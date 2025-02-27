import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class OrdersRequestScreen extends StatefulWidget {
  @override
  _OrdersRequestScreenState createState() => _OrdersRequestScreenState();
}

class _OrdersRequestScreenState extends State<OrdersRequestScreen> {
  List<dynamic> orders = [];
  bool isLoading = true;
  int ?userId;
  int ?buyer_id;
  @override
  void initState() {
    super.initState();
    fetchOrders();
    _fetchLoggedInUsername();
  }

Future<void> _fetchLoggedInUsername() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    final baseUrl = dotenv.env['API_BASE_URL'] ?? '';

    final response = await http.get(
      Uri.parse('$baseUrl/GP/v1/seller/role'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        userId = data['id'];
      });
    } else {
      throw Exception('Failed to fetch id');
    }
  } catch (error) {
    print('Error fetching id: $error');
  }
}

  Future<void> fetchOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not logged in')),
      );
      setState(() {
        isLoading = false;
      });
      return;
    }

    final baseUrl = dotenv.env['API_BASE_URL'] ?? '';
    final apiUrl = Uri.parse('$baseUrl/GP/v1/orders/getOrdersForSeller');

    try {
      final response = await http.get(
        apiUrl,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          orders = data['orders'] ?? [];
          isLoading = false;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to fetch orders')),
        );
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching orders: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error fetching orders')),
      );
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> updateOrderStatus(int orderId, String status, {bool refresh = false}) async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('jwt_token');

  if (token == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('User not logged in')),
    );
    return;
  }

  final baseUrl = dotenv.env['API_BASE_URL'] ?? '';
  final apiUrl = Uri.parse('$baseUrl/GP/v1/orders/updateOrderStatus');

  // Adjust status to fit your backend logic
  final validStatus = status == 'accepted' ? 'completed' : status;

  print('Sending request to $apiUrl with order_id: $orderId and status: $validStatus');

  try {
    final response = await http.patch(
      apiUrl,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'order_id': orderId,
        'status': validStatus,
      }),
    );

    print('Response status: ${response.statusCode}');
    print('Response body: ${response.body}');

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order $status successfully updated.')),
      );

      if (refresh) {
        fetchOrders();
      }

      // Call profit calculation API if the status is 'accepted'
      await calculateProfit(orderId);
      await getBuyerId(orderId); // Ensure buyer_id is set correctly
      await sendOrderResponse(orderId, validStatus, refresh: refresh);
    } else {
      final errorData = json.decode(response.body);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${errorData['message']}')),
      );
    }
  } catch (e) {
    print('Error updating order status: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Failed to update order status')),
    );
  }
}



Future<void> sendOrderResponse(int orderId, String orderResponse, {bool refresh = false}) async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('jwt_token');

  if (token == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('User not logged in')),
    );
    return;
  }

  final baseUrl = dotenv.env['API_BASE_URL'] ?? '';
  final apiUrl = Uri.parse('$baseUrl/GP/v1/orders/respondToOrder');

  try {
    final response = await http.post(
      apiUrl,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'orderId': orderId,
        'response': orderResponse,
      }),
    );

    if (response.statusCode == 200) {
      _sendNotification(userId!, orderResponse);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order $orderResponse successfully responded.')),
      );
      if (refresh) {
        fetchOrders(); // Refresh orders if specified
      }
    } else {
      final errorData = json.decode(response.body);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${errorData['message']}')),
      );
    }
  } catch (e) {
    print('Error responding to order: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Failed to respond to order.')),
    );
  }
}

Future<void> _sendNotification(int receiverId, String status) async {

  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    final baseUrl = dotenv.env['API_BASE_URL'] ?? '';

    final response = await http.post(
      Uri.parse('$baseUrl/GP/v1/notification/notifyUser'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        "userId": receiverId,
        "title": "Gradhub",
        "body": "Order Status: Your order has $status",
      }),
    );

    if (response.statusCode == 200) {
      print('Notification sent successfully');
    } else {
      print('Failed to send notification: ${response.body}');
    }
  } catch (e) {
    print('Error sending notification: $e');
  }
}


  Future<void> calculateProfit(int orderId) async {
    try {
      // Retrieve JWT token from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final String? jwtToken = prefs.getString('jwt_token');
      final baseUrl = dotenv.env['API_BASE_URL'] ?? '';

      if (jwtToken == null) {
        throw Exception('JWT token not found.');
      }

      // Call the calculateProfit API
      final response = await http.get(
        Uri.parse('$baseUrl/GP/v1/orders/calculateProfit'),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Profit Calculation: $data');
        // You can display this data on the UI or store it as needed
      } else {
        print('Failed to calculate profit: ${response.statusCode}');
      }
    } catch (e) {
      print('Error calling calculateProfit: $e');
    }
  }

Future getBuyerId(int orderId) async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('jwt_token');

  if (token == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('User not logged in')),
    );
    return null;
  }

  final baseUrl = dotenv.env['API_BASE_URL'] ?? '';
  final apiUrl = Uri.parse('$baseUrl/GP/v1/orders/getBuyerId?orderId=$orderId');

  try {
    final response = await http.get(
      apiUrl,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        buyer_id = data['buyer_id'] ;
      });
              print(buyer_id);

    } else {
      print('Failed to fetch buyer ID: ${response.statusCode}');
      return null;
    }
  } catch (e) {
    print('Error fetching buyer ID: $e');
    return null;
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders Requests'),
        backgroundColor: const Color(0xFF3B4280),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : orders.isEmpty
              ? const Center(child: Text('No orders found', style: TextStyle(color: Colors.white)))
              : ListView.builder(
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    final orderId = order['order_id'] ?? 'N/A';
                    final totalPrice = order['total_price'] ?? 'N/A';
                    final paymentMethod = order['payment_method'] ?? 'N/A';
                    final items = order['items'] ?? [];

                    return Card(
                      color: Color(0xFF3B4280), // Background color of the card
                      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Order ID: $orderId',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Total Price: $totalPrice NIS',
                              style: const TextStyle(color: Colors.white),
                            ),
                            Text(
                              'Payment Method: $paymentMethod',
                              style: const TextStyle(color: Colors.white),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Items:',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            if (items.isEmpty)
                              const Text('No items found for this order', style: TextStyle(color: Colors.white))
                            else
                              ...items.map<Widget>((item) {
                                final itemDetails = item['item_details'] ?? {};
                                final itemName = itemDetails['name'] ?? 'Unknown';
                                final quantity = item['quantity'] ?? 0;
                                final price = item['price'] ?? 0;

                                return Text(
                                  '$itemName (Qty: $quantity, Price: $price NIS)',
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                );
                              }).toList(),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                              ElevatedButton(
                                onPressed: () => updateOrderStatus(orderId, 'approved', refresh: true), // Sends 'accepted'
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                child: const Text('Approve'),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton(
                                onPressed: () => updateOrderStatus(orderId, 'declined', refresh: true), // Sends 'declined'
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                child: const Text('Decline'),
                              ),

                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
