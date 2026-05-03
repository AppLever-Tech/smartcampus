import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BasicDetailsScreen extends StatefulWidget {
  final bool isAdmin;
  final String orgId;
  const BasicDetailsScreen({Key? key, required this.isAdmin,required this.orgId})
      : super(key: key);

  @override
  State<BasicDetailsScreen> createState() => _BasicDetailsScreenState();
}

class _BasicDetailsScreenState extends State<BasicDetailsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool isEditing = false;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController addressController = TextEditingController();


  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    final doc = await FirebaseFirestore.instance
        .collection('smcOrganizations')
        .doc(widget.orgId)
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      nameController.text = data['name'] ?? '';
      emailController.text = data['email'] ?? '';
      phoneController.text = data['phone'] ?? '';
      addressController.text = data['address'] ?? '';

      setState(() {});
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Organization not found")),
      );
    }
  }

  Future<void> saveData() async {
    final docRef = FirebaseFirestore.instance
        .collection('smcOrganizations')
        .doc(widget.orgId);

    await docRef.set({
      'name': nameController.text,
      'email': emailController.text,
      'phone': phoneController.text,
      'address': addressController.text,
    }, SetOptions(merge: true));

    setState(() {
      isEditing = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Saved successfully")),
    );
  }
  Widget _buildBrightField(
      String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        enabled: isEditing,
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF1F2A44),
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            color: Color(0xFF5C6B8B),
            fontSize: 13,
          ),
          filled: true,
          fillColor: const Color(0xFFF4F7FF),
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFD6E2FF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.blue),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF6F7FB),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
       Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
          "Organization Details",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1F2A44),
          ),
        ),

          if (widget.isAdmin)
            IconButton(
              icon: Icon(
                isEditing ? Icons.save : Icons.edit,
                color: Colors.blue,
              ),
              onPressed: () {
                if (isEditing) {
                  saveData();
                } else {
                  setState(() => isEditing = true);
                }
              },
            ),
        ],
      ),
       ),
      Expanded(
        child : Padding(
         padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Basic Information",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2A44),
              ),
            ),
            const SizedBox(height: 12),


            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF0FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.blue,
                    child: Icon(Icons.business, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      nameController.text.isEmpty
                          ? "Organisation"
                          : nameController.text,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),


            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE3EAF8)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: ListView(
                    children: [
                      _buildBrightField(
                          "Organisation Name", nameController),
                      _buildBrightField("Email", emailController),
                      _buildBrightField("Phone", phoneController),
                      _buildBrightField("Address", addressController),

                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
       ),
      ),
      ],
    ),
    );
  }
}