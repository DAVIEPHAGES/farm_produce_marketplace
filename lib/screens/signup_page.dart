import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _farmNameController = TextEditingController();
  final _farmAddressController = TextEditingController();
  final _farmDescriptionController = TextEditingController();
  final _farmCityController = TextEditingController();
  final _farmDistrictController = TextEditingController();

  bool _isLoading = false;
  String _userType = 'customer';
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _farmNameController.dispose();
    _farmAddressController.dispose();
    _farmDescriptionController.dispose();
    _farmCityController.dispose();
    _farmDistrictController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your phone number';
    }

    String cleanedNumber = value.replaceAll(RegExp(r'[^0-9+]'), '');
    
    if (cleanedNumber.startsWith('0')) {
      if (cleanedNumber.length != 10) {
        return 'Phone number must have exactly 10 digits (e.g., 0999123456)';
      }
      return null;
    } 
    else if (cleanedNumber.startsWith('+265')) {
      if (cleanedNumber.length != 12) {
        return 'Phone number must have exactly 12 digits (e.g., +265999123456)';
      }
      return null;
    } 
    else {
      return 'Invalid phone number. Must start with 0 or +265';
    }
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    if (_userType == 'farmer') {
      if (_farmNameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter your farm name'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      if (_farmAddressController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter your farm address'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      if (_farmCityController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter your farm city/town'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      if (_farmDistrictController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter your farm district'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim().toLowerCase(),
            password: _passwordController.text,
          );

      String cleanedPhone = _phoneController.text.trim().replaceAll(RegExp(r'[^0-9+]'), '');
      
      Map<String, dynamic> userData = {
        'uid': userCredential.user!.uid,
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim().toLowerCase(),
        'phone': cleanedPhone,
        'userType': _userType,
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (_userType == 'farmer') {
        userData.addAll({
          'farmName': _farmNameController.text.trim(),
          'farmAddress': _farmAddressController.text.trim(),
          'farmCity': _farmCityController.text.trim(),
          'farmDistrict': _farmDistrictController.text.trim(),
          'farmDescription': _farmDescriptionController.text.trim(),
          'fullAddress': '${_farmAddressController.text.trim()}, ${_farmCityController.text.trim()}, ${_farmDistrictController.text.trim()}',
          'isVerified': false,
          'rating': 0.0,
          'totalSales': 0,
          'joinDate': FieldValue.serverTimestamp(),
        });
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set(userData);

      String successMessage = '';
      String redirectRoute = '';

      if (_userType == 'farmer') {
        successMessage = 'Farmer account created successfully! Please wait for verification.';
        redirectRoute = '/farmers-dashboard';
      } else {
        successMessage = 'Account created successfully!';
        redirectRoute = '/home';
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.pushReplacementNamed(context, redirectRoute);
        }
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'weak-password':
          errorMessage = 'Password is too weak. Use at least 6 characters.';
          break;
        case 'email-already-in-use':
          errorMessage = 'An account already exists with this email.';
          break;
        case 'invalid-email':
          errorMessage = 'Please enter a valid email address.';
          break;
        default:
          errorMessage = 'Sign up failed: ${e.message}';
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An unexpected error occurred: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 40),

                    const Text(
                      'Farm Produce\nMarketplace',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32),
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Create your account',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 40),

                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: _isLoading ? null : () => setState(() => _userType = 'customer'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _userType == 'customer'
                                      ? const Color(0xFF2E7D32)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.person,
                                      size: 18,
                                      color: _userType == 'customer'
                                          ? Colors.white
                                          : Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Customer',
                                      style: TextStyle(
                                        color: _userType == 'customer'
                                            ? Colors.white
                                            : Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: _isLoading ? null : () => setState(() => _userType = 'farmer'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _userType == 'farmer'
                                      ? const Color(0xFF2E7D32)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.agriculture,
                                      size: 18,
                                      color: _userType == 'farmer'
                                          ? Colors.white
                                          : Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Farmer',
                                      style: TextStyle(
                                        color: _userType == 'farmer'
                                            ? Colors.white
                                            : Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    TextFormField(
                      controller: _nameController,
                      enabled: !_isLoading,
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your full name';
                        }
                        if (value.trim().length < 2) {
                          return 'Name must be at least 2 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _emailController,
                      enabled: !_isLoading,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      validator: _validateEmail,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _phoneController,
                      enabled: !_isLoading,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        prefixIcon: const Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        helperText: 'Format: 0999123456 or +265999123456',
                        hintText: '0999123456 or +265999123456',
                      ),
                      validator: _validatePhone,
                    ),
                    const SizedBox(height: 16),

                    if (_userType == 'farmer') ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info, color: Colors.orange),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Please provide your FARM location details',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _farmNameController,
                        enabled: !_isLoading,
                        decoration: InputDecoration(
                          labelText: 'Farm Name *',
                          prefixIcon: const Icon(Icons.agriculture),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          hintText: 'e.g., Green Valley Farm',
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _farmAddressController,
                        enabled: !_isLoading,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Farm Address/Area *',
                          prefixIcon: const Icon(Icons.location_on_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          hintText: 'e.g., Village, Road, or Landmark',
                        ),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _farmCityController,
                              enabled: !_isLoading,
                              decoration: InputDecoration(
                                labelText: 'City/Town *',
                                prefixIcon: const Icon(Icons.location_city),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _farmDistrictController,
                              enabled: !_isLoading,
                              decoration: InputDecoration(
                                labelText: 'District *',
                                prefixIcon: const Icon(Icons.map),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _farmDescriptionController,
                        enabled: !_isLoading,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Farm Description (Optional)',
                          prefixIcon: const Icon(Icons.description),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          hintText: 'Tell customers about your farming practices, products, etc.',
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    TextFormField(
                      controller: _passwordController,
                      enabled: !_isLoading,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        helperText: 'Minimum 6 characters',
                      ),
                      validator: _validatePassword,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _confirmPasswordController,
                      enabled: !_isLoading,
                      obscureText: _obscureConfirmPassword,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureConfirmPassword = !_obscureConfirmPassword;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      validator: _validateConfirmPassword,
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleSignUp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text(
                                'Create Account',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Already have an account? ', style: TextStyle(color: Colors.grey)),
                        GestureDetector(
                          onTap: _isLoading
                              ? null
                              : () => Navigator.pushReplacementNamed(context, '/signin'),
                          child: const Text(
                            'Sign In',
                            style: TextStyle(
                              color: Color(0xFF2E7D32),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}