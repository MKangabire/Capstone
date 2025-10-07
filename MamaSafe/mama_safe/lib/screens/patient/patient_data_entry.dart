import 'package:flutter/material.dart';

class PatientDataEntry extends StatefulWidget {
  const PatientDataEntry({super.key});

  @override
  State<PatientDataEntry> createState() => _PatientDataEntryState();
}

class _PatientDataEntryState extends State<PatientDataEntry> {
  final _formKey = GlobalKey<FormState>();
  final _bloodGlucoseController = TextEditingController();
  final _bloodPressureSystolicController = TextEditingController();
  final _bloodPressureDiastolicController = TextEditingController();
  final _weightController = TextEditingController();
  final _bmiController = TextEditingController();
  final _pregnancyWeekController = TextEditingController();
  final _ageController = TextEditingController();
  
  bool _isLoading = false;
  String _selectedMealTime = 'Fasting';
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  final List<String> _mealTimes = [
    'Fasting',
    'Before Breakfast',
    'After Breakfast',
    'Before Lunch',
    'After Lunch',
    'Before Dinner',
    'After Dinner',
    'Bedtime',
  ];

  @override
  void dispose() {
    _bloodGlucoseController.dispose();
    _bloodPressureSystolicController.dispose();
    _bloodPressureDiastolicController.dispose();
    _weightController.dispose();
    _bmiController.dispose();
    _pregnancyWeekController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  void _calculateBMI() {
    final weight = double.tryParse(_weightController.text);
    // Assuming height is stored elsewhere or you can add height input
    if (weight != null) {
      // Example calculation with assumed height of 1.65m
      // You should add a height field for accurate BMI
      final bmi = weight / (1.65 * 1.65);
      _bmiController.text = bmi.toStringAsFixed(1);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.pink[400]!,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.pink[400]!,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _submitData() {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      // Simulate API call
      Future.delayed(const Duration(seconds: 2), () {
        setState(() => _isLoading = false);
        
        // Prepare data to return
        final healthData = {
          'age': int.parse(_ageController.text),
          'systolic': double.parse(_bloodPressureSystolicController.text),
          'diastolic': double.parse(_bloodPressureDiastolicController.text),
          'bloodGlucose': double.parse(_bloodGlucoseController.text),
          'weight': double.parse(_weightController.text),
          'bmi': double.tryParse(_bmiController.text),
          'pregnancyWeek': int.parse(_pregnancyWeekController.text),
          'mealTime': _selectedMealTime,
          'timestamp': DateTime.now().toIso8601String(),
        };
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Health data saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Return data and go back to dashboard
        Navigator.pop(context, healthData);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Enter Health Data"),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Info Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Please enter your current health metrics accurately for better risk assessment.",
                          style: TextStyle(
                            color: Colors.blue[900],
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Date and Time Section
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectDate(context),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: Colors.pink[100]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today,
                                  color: Colors.pink[400], size: 20),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Date",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  Text(
                                    "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}",
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectTime(context),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: Colors.pink[100]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.access_time,
                                  color: Colors.pink[400], size: 20),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Time",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  Text(
                                    _selectedTime.format(context),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Personal Information Section
                _buildSectionHeader("Personal Information", Icons.person),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Age",
                    hintText: "Enter your age",
                    prefixIcon: Icon(Icons.cake_outlined),
                    suffixText: "years",
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your age';
                    }
                    final age = int.tryParse(value);
                    if (age == null || age < 18 || age > 50) {
                      return 'Please enter a valid age (18-50)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _pregnancyWeekController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Pregnancy Week",
                    hintText: "Current week of pregnancy",
                    prefixIcon: Icon(Icons.child_care),
                    suffixText: "weeks",
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter pregnancy week';
                    }
                    final week = int.tryParse(value);
                    if (week == null || week < 1 || week > 42) {
                      return 'Please enter a valid week (1-42)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Blood Glucose Section
                _buildSectionHeader("Blood Glucose", Icons.bloodtype),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  initialValue: _selectedMealTime,
                  decoration: const InputDecoration(
                    labelText: "Meal Time",
                    prefixIcon: Icon(Icons.restaurant_menu),
                  ),
                  items: _mealTimes.map((String time) {
                    return DropdownMenuItem(
                      value: time,
                      child: Text(time),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedMealTime = newValue!;
                    });
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _bloodGlucoseController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Blood Glucose Level",
                    hintText: "Enter glucose level",
                    prefixIcon: Icon(Icons.water_drop_outlined),
                    suffixText: "mg/dL",
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter blood glucose level';
                    }
                    final glucose = double.tryParse(value);
                    if (glucose == null || glucose < 50 || glucose > 400) {
                      return 'Please enter a valid value (50-400)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Blood Pressure Section
                _buildSectionHeader("Blood Pressure", Icons.favorite_border),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _bloodPressureSystolicController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "Systolic",
                          hintText: "120",
                          prefixIcon: Icon(Icons.arrow_upward),
                          suffixText: "mmHg",
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          final sys = int.tryParse(value);
                          if (sys == null || sys < 70 || sys > 200) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _bloodPressureDiastolicController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "Diastolic",
                          hintText: "80",
                          prefixIcon: Icon(Icons.arrow_downward),
                          suffixText: "mmHg",
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          final dia = int.tryParse(value);
                          if (dia == null || dia < 40 || dia > 130) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Body Measurements Section
                _buildSectionHeader("Body Measurements", Icons.monitor_weight),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _weightController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Weight",
                    hintText: "Enter your weight",
                    prefixIcon: Icon(Icons.monitor_weight_outlined),
                    suffixText: "kg",
                  ),
                  onChanged: (value) => _calculateBMI(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your weight';
                    }
                    final weight = double.tryParse(value);
                    if (weight == null || weight < 30 || weight > 200) {
                      return 'Please enter a valid weight (30-200 kg)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _bmiController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: "BMI (Auto-calculated)",
                    hintText: "Will be calculated",
                    prefixIcon: const Icon(Icons.calculate_outlined),
                    suffixText: "kg/m²",
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                ),
                const SizedBox(height: 32),

                // Submit Button
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitData,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.save),
                              SizedBox(width: 8),
                              Text("Save Health Data"),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.pink[400], size: 24),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }
}