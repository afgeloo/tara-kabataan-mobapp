import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:dotted_border/dotted_border.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';

class MembersTab extends StatefulWidget {
  const MembersTab({super.key});

  @override
  State<MembersTab> createState() => _MembersTabState();
}

class _MembersTabState extends State<MembersTab> {
  late Future<List<Map<String, dynamic>>> _membersFuture;
  late Future<List<Map<String, dynamic>>> _rolesFuture;
  List<Map<String, dynamic>> _roles = []; // Will be populated from API

  @override
  void initState() {
    super.initState();
    _membersFuture = fetchMembers();
    _rolesFuture = fetchRoles();
    _rolesFuture.then((roles) {
      setState(() {
        _roles = roles;
      });
    });
  }

  Future<List<Map<String, dynamic>>> fetchMembers() async {
    final response = await http.get(
      Uri.parse('http://10.0.2.2/tara-kabataan/tara-kabataan-backend/api/members.php'),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['success'] == true) {
        return List<Map<String, dynamic>>.from(json['members']);
      }
    }
    throw Exception('Failed to load members');
  }

  Future<List<Map<String, dynamic>>> fetchRoles() async {
    try {
      final response = await http.get(
        Uri.parse('http://10.0.2.2/tara-kabataan/tara-kabataan-backend/api/roles.php'),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true) {
          return List<Map<String, dynamic>>.from(json['roles']);
        }
      }
      // If there's an error, return an empty list
      return [];
    } catch (e) {
      debugPrint('Error fetching roles: $e');
      // Return empty list on error
      return [];
    }
  }

  void _showMemberDialog(Map<String, dynamic> member) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFFF6F6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'MEMBER DETAILS',
              style: TextStyle(
                fontFamily: 'Bogart',
                fontWeight: FontWeight.w900,
                fontSize: 22,
                color: Color(0xFF3D3D3D),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.black54),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Display member image with error handling
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[300],
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipOval(
                child: member['member_image'] != null && member['member_image'].isNotEmpty
                  ? Image.network(
                      'http://10.0.2.2/${member['member_image']}',
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.person, size: 50, color: Colors.white70);
                      },
                    )
                  : const Icon(Icons.person, size: 50, color: Colors.white70),
              ),
            ),
            const SizedBox(height: 16),
            Text(member['member_name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(member['role_name'], style: const TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: () => _editMember(member),
                  icon: const Icon(Icons.edit, color: Colors.white),
                  label: const Text('Edit', style: TextStyle(color: Colors.white)),
                  style: TextButton.styleFrom(backgroundColor: const Color(0xFF4DB1E3)),
                ),
                const SizedBox(width: 12),
                TextButton.icon(
                  onPressed: () => _deleteMember(member['member_id']),
                  icon: const Icon(Icons.delete, color: Colors.white),
                  label: const Text('Delete', style: TextStyle(color: Colors.white)),
                  style: TextButton.styleFrom(backgroundColor: const Color(0xFFE94B4B)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _editMember(Map<String, dynamic> member) {
    Navigator.pop(context); // Close the member dialog
    
    // Create controllers and variables for the edit dialog
    final nameController = TextEditingController(text: member['member_name']);
    String? selectedRoleId = member['role_id'];
    String? memberImage = member['member_image'];
    XFile? newImage;
    bool isSaving = false;
    final picker = ImagePicker();
    
    // Show custom edit dialog
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent closing by tapping outside
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFFFFF6F6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Edit Member', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    final picked = await picker.pickImage(source: ImageSource.gallery);
                    if (picked != null) {
                      setDialogState(() => newImage = picked);
                    }
                  },
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey[300],
                    child: _buildProfileImage(newImage, memberImage),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  ),
                ),
                const SizedBox(height: 12),
                _roles.isEmpty
                  ? Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Center(
                        child: SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : DropdownButtonFormField<String>(
                      value: selectedRoleId,
                      hint: const Text('Select Role'),
                      isExpanded: true,
                      items: _roles
                          .map((role) => DropdownMenuItem(
                                value: role['role_id'].toString(),
                                child: Text(role['role_name'].toString()),
                              ))
                          .toList(),
                      onChanged: (val) => setDialogState(() => selectedRoleId = val),
                      decoration: const InputDecoration(
                        labelText: 'Role',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      validator: (value) => value == null ? 'Please select a role' : null,
                    ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: isSaving ? null : () async {
                setDialogState(() => isSaving = true);
                
                try {
                  final memberId = member['member_id'];
                  
                  // Try to upload image if selected, but continue even if it fails
                  if (newImage != null) {
                    try {
                      await _uploadMemberImage(memberId, newImage!);
                      // If successful, update the memberImage variable
                      final response = await http.get(
                        Uri.parse('http://10.0.2.2/tara-kabataan/tara-kabataan-backend/api/members.php?member_id=$memberId'),
                      );
                      final result = jsonDecode(response.body);
                      if (result['success'] == true && result['members'].isNotEmpty) {
                        memberImage = result['members'][0]['member_image'];
                      }
                    } catch (e) {
                      // Log error but continue with member update
                      print("Image upload error: $e");
                    }
                  }
                  
                  // Update member data
                  final payload = {
                    'member_id': memberId,
                    'member_name': nameController.text.trim(),
                    'role_id': selectedRoleId ?? '',
                  };
                  
                  final response = await http.post(
                    Uri.parse('http://10.0.2.2/tara-kabataan/tara-kabataan-backend/api/update_member.php'),
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode(payload),
                  );
                  
                  final result = jsonDecode(response.body);
                  if (result['success'] == true) {
                    setState(() {
                      _membersFuture = fetchMembers(); // Refresh list after editing
                    });
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Member updated successfully")),
                    );
                  } else {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(content: Text("Error: ${result['message'] ?? 'Unknown error'}"))
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text("Error: $e"))
                  );
                }
                
                setDialogState(() => isSaving = false);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4DB1E3)),
              child: isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
  
  // Helper method to build profile image widget
  Widget _buildProfileImage(XFile? newImage, String? memberImage) {
    if (newImage != null) {
      // Show selected image from device
      return ClipOval(
        child: Image.file(
          File(newImage.path),
          width: 100,
          height: 100,
          fit: BoxFit.cover,
        ),
      );
    } else if (memberImage != null && memberImage.isNotEmpty) {
      // Show existing image from server
      return ClipOval(
        child: Image.network(
          'http://10.0.2.2$memberImage',
          width: 100,
          height: 100,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(Icons.camera_alt, size: 32, color: Colors.white);
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          },
        ),
      );
    } else {
      // Show placeholder
      return const Icon(Icons.camera_alt, size: 32, color: Colors.white);
    }
  }
  
  // Helper method to upload member image
  Future<void> _uploadMemberImage(String memberId, XFile image) async {
    try {
      final uri = Uri.parse("http://10.0.2.2/tara-kabataan/tara-kabataan-backend/api/upload_member_image.php");
      final request = http.MultipartRequest('POST', uri);
      request.fields['member_id'] = memberId;
      request.files.add(await http.MultipartFile.fromPath('image', image.path));

      final response = await request.send();
      final resBody = await response.stream.bytesToString();
      
      // Safely try to parse the JSON response
      Map<String, dynamic> data;
      try {
        data = jsonDecode(resBody);
        
        if (data['success'] != true) {
          // Log error but don't throw exception
          print("Upload warning: ${data['message'] ?? 'Unknown error'}");
        }
      } catch (e) {
        // Handle invalid JSON response
        print("Invalid JSON response from image upload: $resBody");
      }
    } catch (e) {
      // Log error but continue with member update
      print("Image upload error: $e");
      // We don't throw here to allow member updates without image
    }
  }

  Future<void> _deleteMember(String memberId) async {
    // First close the member details dialog
    Navigator.of(context).pop();
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Member"),
        content: const Text("Are you sure you want to delete this member?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete")),
        ],
      ),
    );

    if (confirm == true) {
      final response = await http.post(
        Uri.parse('http://10.0.2.2/tara-kabataan/tara-kabataan-backend/api/delete_member.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"member_id": memberId}),
      );

      final result = jsonDecode(response.body);
      if (result['success'] == true) {
        setState(() {
          _membersFuture = fetchMembers();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Member deleted successfully.")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to delete: ${result['error']}")),
        );
      }
    }
  }
  
  void _showAddMemberDialog() {
    // Create controllers and variables for the add dialog
    final nameController = TextEditingController();
    String? selectedRoleId;
    XFile? newImage;
    bool isSaving = false;
    final picker = ImagePicker();
    
    // Show custom add dialog
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent closing by tapping outside
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFFFFF6F6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add New Member', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    final picked = await picker.pickImage(source: ImageSource.gallery);
                    if (picked != null) {
                      setDialogState(() => newImage = picked);
                    }
                  },
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey[300],
                    child: newImage != null
                      ? ClipOval(
                          child: Image.file(
                            File(newImage!.path),
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                        )
                      : const Icon(Icons.camera_alt, size: 32, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  ),
                ),
                const SizedBox(height: 12),
                _roles.isEmpty
                  ? Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Center(
                        child: SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : DropdownButtonFormField<String>(
                      value: selectedRoleId,
                      hint: const Text('Select Role'),
                      isExpanded: true,
                      items: _roles
                          .map((role) => DropdownMenuItem(
                                value: role['role_id'].toString(),
                                child: Text(role['role_name'].toString()),
                              ))
                          .toList(),
                      onChanged: (val) => setDialogState(() => selectedRoleId = val),
                      decoration: const InputDecoration(
                        labelText: 'Role',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      validator: (value) => value == null ? 'Please select a role' : null,
                    ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(foregroundColor: Colors.grey),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSaving ? null : () async {
                // Validate inputs
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text("Please enter a name"))
                  );
                  return;
                }
                
                if (selectedRoleId == null) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text("Please select a role"))
                  );
                  return;
                }
                
                setDialogState(() => isSaving = true);
                
                try {
                  // First create the member
                  final createPayload = {
                    'member_name': nameController.text.trim(),
                    'role_id': selectedRoleId,
                  };
                  
                  final response = await http.post(
                    Uri.parse('http://10.0.2.2/tara-kabataan/tara-kabataan-backend/api/add_new_member.php'),
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode(createPayload),
                  );
                  
                  // Check if the response is valid JSON
                  Map<String, dynamic> result;
                  try {
                    result = jsonDecode(response.body);
                  } catch (e) {
                    print("Invalid JSON response: ${response.body}");
                    throw Exception("Server returned invalid response format. Please check the API endpoint.");
                  }
                  
                  if (result['success'] == true) {
                    final String newMemberId = result['member_id'] ?? '';
                    
                    // If we have an image and a valid member ID, upload it
                    if (newImage != null && newMemberId.isNotEmpty) {
                      try {
                        await _uploadMemberImage(newMemberId, newImage!);
                      } catch (e) {
                        // Log error but continue
                        print("Image upload error: $e");
                      }
                    }
                    
                    // Refresh the members list
                    setState(() {
                      _membersFuture = fetchMembers();
                    });
                    
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Member added successfully"),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(content: Text("Error: ${result['message'] ?? 'Unknown error'}"))
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text("Error: $e"))
                  );
                }
                
                setDialogState(() => isSaving = false);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4DB1E3)),
              child: isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _membersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final members = snapshot.data ?? [];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = (constraints.maxWidth - 16) / 2;
              return SingleChildScrollView(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ...members.map((member) => _MemberCard(
                          name: member['member_name'],
                          role: member['role_name'],
                          imageUrl: 'http://10.0.2.2/${member['member_image']}',
                          onTap: () => _showMemberDialog(member),
                          width: itemWidth,
                        )),
                    _AddMemberTile(
                      onTap: () => _showAddMemberDialog(),
                      width: itemWidth,
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _MemberCard extends StatelessWidget {
  final String name;
  final String role;
  final String imageUrl;
  final VoidCallback onTap;
  final double width;

  const _MemberCard({
    required this.name,
    required this.role,
    required this.imageUrl,
    required this.onTap,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    // Clean image URL and handle empty URLs
    final bool hasValidImage = imageUrl.isNotEmpty && imageUrl != 'http://10.0.2.2/';
    final sanitizedPath = hasValidImage && imageUrl.startsWith('//')
        ? imageUrl.replaceFirst('//', '/')
        : imageUrl;
    final fullUrl = sanitizedPath;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.only(left: 60, right: 16),
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const SizedBox(width: 40),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text(role, style: const TextStyle(fontSize: 13, color: Colors.grey), overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 10,
              left: 0,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [Color(0xFFFF5A89), Color(0xFF4DB1E3)]),
                ),
                child: CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: ClipOval(
                    child: hasValidImage
                      ? CachedNetworkImage(
                          imageUrl: fullUrl,
                          width: 54,
                          height: 54,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                            ),
                          ),
                          errorWidget: (context, url, error) => const Icon(Icons.person, size: 30, color: Colors.grey),
                        )
                      : const Icon(Icons.person, size: 30, color: Colors.grey),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _AddMemberTile extends StatelessWidget {
  final VoidCallback onTap;
  final double width;

  const _AddMemberTile({required this.onTap, required this.width});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: DottedBorder(
        color: Colors.grey.shade400,
        borderType: BorderType.RRect,
        radius: const Radius.circular(16),
        dashPattern: const [6, 3],
        strokeWidth: 1.5,
        child: Container(
          width: width,
          height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, color: Colors.grey),
                SizedBox(height: 4),
                Text('Add Member', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
