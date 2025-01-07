import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_project/screens/Shop/cart_screen.dart';
import 'package:flutter_project/components/MenuSideBar/side_bar_menu.dart';
import 'package:flutter_project/screens/Shop/item_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:badges/badges.dart' as badges;
import 'package:flutter_project/widgets/categories_widget.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart'; // For base64 decoding if needed
import 'dart:typed_data';

class ShopHomePage extends StatefulWidget {
  const ShopHomePage({super.key});

  @override
  _ShopHomePageState createState() => _ShopHomePageState();
}

class _ShopHomePageState extends State<ShopHomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>(); // GlobalKey for Scaffold
  File? _image; // To store the image file
  int _cartItemCount = 0; // Track cart item count
  List<dynamic> items = []; // Store fetched items
  bool isLoading = false; // Loading state for items
  String selectedCategory = ''; // Store selected category
  bool hasPhoneNumber = false; // Track whether user has phone number or not
  TextEditingController _searchController = TextEditingController(); // Search controller

  // Function to open the camera
  Future<void> _openCamera() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedImage = await picker.pickImage(source: ImageSource.camera);

    if (pickedImage != null) {
      setState(() {
        _image = File(pickedImage.path); // Convert the picked image to a File
      });
    }
  }

  // Function to increment the cart item count
  void _incrementCartItemCount() {
    setState(() {
      _cartItemCount++;
    });
  }

  // Function to decrement the cart item count
  void _decrementCartItemCount() {
    setState(() {
      if (_cartItemCount > 0) {
        _cartItemCount--;
      }
    });
  }


Future<void> searchItems(String query) async {
  if (query.isEmpty) {
    fetchItems(); // Fetch all items if search query is empty
    return;
  }

  final itemsUrl = Uri.parse('${dotenv.env['API_BASE_URL']}/GP/v1/seller/items/searchItems')
      .replace(queryParameters: {'item_name': query});

  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('jwt_token');

  if (token == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('User not logged in')),
    );
    return;
  }

  try {
    setState(() {
      isLoading = true; // Start loading
    });

    final response = await http.get(
      itemsUrl,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print(data); // Add this line to print the raw response to check its structure
      if (data != null && data is Map<String, dynamic> && data.containsKey('items')) {
        setState(() {
          items = List.from(data['items'] ?? []); // Update items list
          isLoading = false; // Stop loading when data is received
        });
      } else {
        setState(() {
          items = [];
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No items found')),
        );
      }
    } else {
      setState(() {
        isLoading = false;
      });
    }
  } catch (e) {
    print("Error searching items: $e");
    setState(() {
      isLoading = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Error searching items')),
    );
  }
}

Future<void> fetchItems() async {
  final itemsUrl = Uri.parse('${dotenv.env['API_BASE_URL']}/GP/v1/seller/items/getAllItems');
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('jwt_token');

  if (token == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('User not logged in')),
    );
    return;
  }

  try {
    setState(() {
      isLoading = true; // Start loading
    });

    final response = await http.get(
      itemsUrl,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print(data); // Add this line to print the raw response to check its structure
      if (data != null && data is Map<String, dynamic> && data.containsKey('items')) {
        setState(() {
          items = List.from(data['items'] ?? []); // Update items list
          isLoading = false; // Stop loading when data is received
        });
        
      } else {
        setState(() {
          items = [];
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No items found')),
        );
      }
    } else {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load items')),
      );
    }
  } catch (e) {
    print("Error fetching items: $e");
    setState(() {
      isLoading = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Error fetching items')),
    );
  }
}

  // Function to fetch items by category
  Future<void> fetchItemsByCategory(String category) async {
    if (category == "All") {
      fetchItems(); // Call fetchItems to get all items
      return;
    }

    final itemsUrl = Uri.parse('${dotenv.env['API_BASE_URL']}/GP/v1/seller/items/getItemsByCategory')
        .replace(queryParameters: {'Category': category});  // Send category as a query parameter

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not logged in')),
      );
      return;
    }

    try {
      setState(() {
        isLoading = true; // Start loading
        selectedCategory = category; // Set selected category
      });

      final response = await http.get(
        itemsUrl,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print("API Response (Category): $data");  // Log the API response

        if (data != null && data is Map<String, dynamic> && data.containsKey('items')) {
          setState(() {
            items = List.from(data['items'] ?? []); // Update items state with fetched data
            isLoading = false; // Stop loading when data is received
          });
        } else {
          setState(() {
            items = []; // No items found for the selected category
            isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No items found in this category')),
          );
        }
      } else {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No items found in this category')),
        );
      }
    } catch (e) {
      print("Error fetching items by category: $e");
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error fetching items by category')),
      );
    }
  }

  // Function to check if the user has a phone number
  Future<void> checkPhoneNumber() async {
    final prefs = await SharedPreferences.getInstance();
    final phoneNumber = prefs.getString('phone_number'); // Retrieve phone number from SharedPreferences

    if (phoneNumber == null || phoneNumber.isEmpty) {
      // If the phone number is missing, show the dialog
      _showPhoneNumberDialog();
    } else {
      setState(() {
        hasPhoneNumber = true; // User already has a phone number
      });
    }
  }

Future<void> _showPhoneNumberDialog() async {
  final TextEditingController phoneNumberController = TextEditingController(); // Create the controller here

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text('Please enter your phone number'),
        content: TextField(
          controller: phoneNumberController, // Assign the controller to the TextField
          decoration: InputDecoration(hintText: 'Enter phone number'),
          keyboardType: TextInputType.phone,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close the dialog
            },
            child: Text('Not now'),
          ),
          TextButton(
            onPressed: () async {
              String phoneNumber = phoneNumberController.text.trim();
              if (phoneNumber.isNotEmpty) {
                // Update the phone number in SharedPreferences
                final prefs = await SharedPreferences.getInstance();
                prefs.setString('phone_number', phoneNumber);

                // Call the API to update the phone number
                await updateProfile(phoneNumber);

                Navigator.pop(context); // Close the dialog
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Phone number cannot be empty')),
                );
              }
            },
            child: Text('Add'),
          ),
        ],
      );
    },
  );
}

Future<void> updateProfile(String newPhoneNumber) async {
  final baseUrl = dotenv.env['API_BASE_URL'] ?? '';
  final updateUrl = Uri.parse('${baseUrl}/GP/v1/users/updatePhoneNumber');
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('jwt_token');

  if (token == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('User not logged in')),
    );
    return;
  }

  if (newPhoneNumber.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Phone number cannot be empty')),
    );
    return;
  }

  print('Sending Phone Number: $newPhoneNumber'); // Debugging: print the phone number

  Map<String, dynamic> updates = {'phone_number': newPhoneNumber};

  try {
    final response = await http.patch(
      updateUrl,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode(updates),
    );

    print('Response Status: ${response.statusCode}'); // Debugging: log status code
    print('Response Body: ${response.body}'); // Debugging: print response body

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
    } else {
      final errorData = json.decode(response.body);
      print('Error: ${errorData['message']}'); // Debugging: print the error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${errorData['message']}')),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Network error')),
    );
    print('Error: $e'); // Log the error
  }
}


  @override
  void initState() {
    super.initState();
    fetchItems(); // Fetch all items when the page loads
    checkPhoneNumber(); // Check if user has phone number
  }


@override
Widget build(BuildContext context) {
  return Scaffold(
    key: _scaffoldKey,
    drawer: SideMenu(),
    body: ListView(
      children: [
        // App Bar and other widgets remain the same
        Container(
          color: Colors.white,
          padding: EdgeInsets.all(25),
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  _scaffoldKey.currentState?.openDrawer();
                },
                child: Icon(
                  Icons.sort,
                  size: 30,
                  color: Color(0xFF3B4280),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(left: 20),
                child: Text(
                  "Components Shop",
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3B4280),
                  ),
                ),
              ),
              Spacer(),
              badges.Badge(
                showBadge: _cartItemCount > 0,
                badgeStyle: badges.BadgeStyle(
                  badgeColor: Colors.red,
                  padding: EdgeInsets.all(7),
                ),
                badgeContent: Text(
                  _cartItemCount.toString(),
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CartScreen(),
                        ),
                      );
                    },
                    child: Icon(
                      Icons.shopping_bag_outlined,
                      size: 32,
                      color: Color(0xFF3B4280),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Search Widget
        Container(
          margin: EdgeInsets.symmetric(horizontal: 0),
          padding: EdgeInsets.symmetric(horizontal: 15),
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            children: [
              Container(
                margin: EdgeInsets.only(left: 5),
                height: 50,
                width: 298,
                child: TextFormField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: "Search here...",
                  ),
                  onChanged: (query) {
                    searchItems(query); // Call search function on text change
                  },
                ),
              ),
              Spacer(),
              IconButton(
                icon: Icon(
                  Icons.camera_alt,
                  size: 27,
                  color: Color(0xFF3B4280),
                ),
                onPressed: _openCamera,
              ),
            ],
          ),
        ),
        // Categories Widget remains the same
        Container(
          alignment: Alignment.centerLeft,
          margin: EdgeInsets.symmetric(vertical: 20, horizontal: 10),
          child: Text(
            "Categories",
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3B4280),
            ),
          ),
        ),
        CategoriesWidget(
          onCategorySelected: (category) {
            fetchItemsByCategory(category);
          },
        ),
        // Items Section
        const SizedBox(height: 8),
        isLoading
            ? const Center(child: CircularProgressIndicator())
            : items.isEmpty
                ? Center(child: Text('No items found'))
                : GridView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(), // Disable independent scrolling
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 0.7,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];  // Make sure this is a Map<String, dynamic>
                    if (item is Map<String, dynamic>) {
                      return ItemCard(
                        item: item,  // Pass the map to the ItemCard
                      );
                    } else {
                      return const SizedBox(); // Handle invalid data gracefully
                    }
                  },
                )

      ],
    ),
  );
}
}

class ItemCard extends StatefulWidget {
  final Map<String, dynamic> item;

  const ItemCard({
    Key? key,
    required this.item,
  }) : super(key: key);

  @override
  _ItemCardState createState() => _ItemCardState();
}

class _ItemCardState extends State<ItemCard> {
  bool isFavorite = false; // Track whether the item is in favorites

  @override
  void initState() {
    super.initState();
    checkIfFavorite(); // Check the initial favorite state
  }

  Future<void> checkIfFavorite() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    if (token == null) return;

    try {
      final response = await http.get(
        Uri.parse('${dotenv.env['API_BASE_URL']}/GP/v1/shop/favoriteItems/checkFavoriteItem/${widget.item['Item_ID']}'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          isFavorite = true; // Set to true if item is in favorites
        });
      }
    } catch (e) {
      print("Error checking favorite status: $e");
    }
  }

  Future<void> toggleFavorite() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not logged in')),
      );
      return;
    }

    try {
      if (isFavorite) {
        // Remove from favorites
        final response = await http.delete(
          Uri.parse('${dotenv.env['API_BASE_URL']}/GP/v1/shop/favoriteItems/removeFavoriteItem'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({"item_id": widget.item['Item_ID']}),
        );

        if (response.statusCode == 200) {
          setState(() {
            isFavorite = false; // Update UI to show unfilled icon
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Item removed from favorites')),
          );
        }
      } else {
        // Add to favorites
        final response = await http.post(
          Uri.parse('${dotenv.env['API_BASE_URL']}/GP/v1/shop/favoriteItems/addFavoriteItem'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({"item_id": widget.item['Item_ID']}),
        );

        if (response.statusCode == 200) {
          setState(() {
            isFavorite = true; // Update UI to show filled icon
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Item added to favorites')),
          );
        }
      }
    } catch (e) {
      print("Error toggling favorite status: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update favorite status')),
      );
    }
  }


  Future<void> addToCart(BuildContext context, int itemId, int quantity, int price) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User not logged in')),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('${dotenv.env['API_BASE_URL']}/GP/v1/shop/cart/createOrUpdateCart'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "items": [
            {"item_id": itemId, "quantity": quantity, "price": price}
          ]
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Item added to cart successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add item to cart')),
        );
      }
    } catch (e) {
      print("Error adding to cart: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding item to cart')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    String itemName = widget.item['item_name'] ?? 'No name';
    String description = widget.item['Description'] ?? 'No description';
    int price = int.tryParse(widget.item['Price'].toString()) ?? 0;
    int itemId = int.tryParse(widget.item['Item_ID'].toString()) ?? 0;
    String base64Image = widget.item['Picture'] ?? '';

    Uint8List? imageBytes;
    if (base64Image.isNotEmpty) {
      try {
        imageBytes = base64Decode(base64Image);
      } catch (e) {
        print("Error decoding Base64 image: $e");
      }
    }

    Widget imageWidget = imageBytes != null && imageBytes.isNotEmpty
        ? Image.memory(imageBytes, width: double.infinity, height: 160, fit: BoxFit.cover)
        : Center(child: Text('No image available', style: TextStyle(color: Colors.grey)));

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ItemScreen(item: widget.item),
          ),
        );
      },
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: imageWidget,
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    itemName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF3B4280)),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    description,
                    style: TextStyle(fontSize: 12, color: Colors.black87),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "$price NIS",
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              isFavorite ? Icons.favorite : Icons.favorite_border,
                              color: Colors.red,
                              size: 20,
                            ),
                            onPressed: toggleFavorite, // Call toggleFavorite on press
                          ),
                          IconButton(
                            icon: Icon(Icons.shopping_cart_outlined, color: Color(0xFF3B4280), size: 20),
                            onPressed: () {
                              addToCart(context, widget.item['Item_ID'], 1, price);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


