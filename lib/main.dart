import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  runApp(const MyApp());
}


class Product {
  final int id;
  final String name;
  final double price;
  final String description;

  Product({
    required this.id, 
    required this.name, 
    required this.price, 
    required this.description
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      name: json['name'],
      price: double.parse(json['price'].toString()),
      description: json['description'] ?? '',
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tugas PBM 2026',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      home: const LoginPage(),
    );
  }
}


class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final storage = const FlutterSecureStorage();
  bool _isLoading = false;

  Future<void> login() async {
    setState(() => _isLoading = true);
    
    final url = Uri.parse('https://task.itprojects.web.id/api/auth/login'); 
    
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'username': _usernameController.text, 
          'password': _passwordController.text, 
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String token = data['data']['token']; 
        
        await storage.write(key: 'token', value: token);
        
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const ProductCatalogPage()),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Login Gagal! Periksa NIM Anda.')),
          );
        }
      }
    } catch (e) {
      print(e);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login Mahasiswa')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'NIM',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 25),
            _isLoading 
              ? const CircularProgressIndicator()
              : ElevatedButton(
                  onPressed: login, 
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                  child: const Text('MASUK'),
                ),
          ],
        ),
      ),
    );
  }
}


class ProductCatalogPage extends StatefulWidget {
  const ProductCatalogPage({super.key});

  @override
  State<ProductCatalogPage> createState() => _ProductCatalogPageState();
}

class _ProductCatalogPageState extends State<ProductCatalogPage> {
  // Tambahkan opsi iOS agar secure storage lancar di simulator
  final storage = const FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
  List<Product> products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchProducts();
  }

  // FUNGSI GET: Mengambil data produk milik sendiri [cite: 110, 111]
  Future<void> fetchProducts() async {
    String? token = await storage.read(key: 'token');
    final url = Uri.parse('https://task.itprojects.web.id/api/products');

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token', // [cite: 4, 149]
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          products = (data['data']['products'] as List)
              .map((item) => Product.fromJson(item))
              .toList(); // [cite: 330]
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // FUNGSI POST: Menyimpan draft produk baru [cite: 37, 135]
  void _showAddProductDialog() {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah Draft Produk'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nama Produk')),
            TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: 'Harga'), keyboardType: TextInputType.number),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Deskripsi')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              // Validasi input harga agar tidak error saat parse
              final price = int.tryParse(priceCtrl.text);
              if (price == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Harga harus berupa angka!')),
                );
                return;
              }

              String? token = await storage.read(key: 'token');
              try {
                final res = await http.post(
                  Uri.parse('https://task.itprojects.web.id/api/products'),
                  headers: {
                    'Authorization': 'Bearer $token',
                    'Content-Type': 'application/json',
                    'Accept': 'application/json',
                  },
                  body: jsonEncode({
                    'name': nameCtrl.text,
                    'price': price,
                    'description': descCtrl.text,
                  }),
                );
                
                if (res.statusCode == 201 || res.statusCode == 200) {
                  if (mounted) {
                    Navigator.pop(context);
                    fetchProducts(); // Refresh list
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Produk berhasil ditambahkan!')),
                    );
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Gagal menambah produk: ${res.statusCode}')),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Terjadi kesalahan: $e')),
                  );
                }
              }
            }, 
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  // FUNGSI SUBMIT: Mengirim tugas & GitHub ke asisten [cite: 48, 156]
  void _showSubmitDialog() {
    final githubCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit Tugas (GitHub)'),
        content: TextField(controller: githubCtrl, decoration: const InputDecoration(hintText: "Link Repo GitHub Pribadi")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              String? token = await storage.read(key: 'token');
              final response = await http.post(
                Uri.parse('https://task.itprojects.web.id/api/products/submit'),
                headers: {
                  'Authorization': 'Bearer $token',
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
                body: jsonEncode({
                  "name": "Tugas PBM NIM 232410103056",
                  "price": 0,
                  "description": "Selesai",
                  "github_url": githubCtrl.text // [cite: 53, 162]
                }),
              );
              if (response.statusCode == 201) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tugas Berhasil Disubmit!')));
                Navigator.pop(context);
              }
            }, 
            child: const Text('Kirim'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Katalog Produk'),
        actions: [
          // Tombol Pesawat untuk Submit Tugas [cite: 334]
          IconButton(icon: const Icon(Icons.send), onPressed: _showSubmitDialog),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await storage.delete(key: 'token');
              if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage()));
            },
          )
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            itemCount: products.length,
            itemBuilder: (context, index) {
              final p = products[index];
              return Card(child: ListTile(title: Text(p.name), subtitle: Text(p.description), trailing: Text('Rp ${p.price}')));
            },
          ),
      // SEKARANG SUDAH ADA FUNGSI PANGGIL DIALOG [cite: 41]
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddProductDialog, 
        child: const Icon(Icons.add),
      ),
    );
  }
}