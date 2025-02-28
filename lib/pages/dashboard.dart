import 'package:flutter/material.dart';
import 'package:green_ride/pages/bottom_nav/earnings.dart';
import 'package:green_ride/pages/bottom_nav/home.dart';
import 'package:green_ride/pages/bottom_nav/profile.dart';
import 'package:green_ride/pages/bottom_nav/trips.dart';


class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard>
    with SingleTickerProviderStateMixin {
  late TabController tabController;
  int selectedIndex = 0;

  void onBarItemClicked(int i) {
    setState(() {
      selectedIndex = i;
      tabController.index = selectedIndex;
    });
  }

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TabBarView(
        physics: const NeverScrollableScrollPhysics(),
        controller: tabController,
        children: const [
          HomePage(),
          ProfilePage(),
          Earnings(),
          Trips(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: onBarItemClicked,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: "Profile",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.money),
            label: "Earnings",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_car),
            label: "Trips",
          ),
        ],
        unselectedItemColor: Colors.grey,
        selectedItemColor: Colors.pink,
        showSelectedLabels: true,
        selectedLabelStyle: const TextStyle(
          fontSize: 12,
        ),
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
