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
  TabController? tabController;
  int selectedIndex = 0;

  onBarItemClicked(int i) {
    setState(() {
      selectedIndex = i;
      tabController!.index = selectedIndex;
    });
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    // TODO: implement dispose
    tabController!.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TabBarView(
        physics: const NeverScrollableScrollPhysics(),
        controller: tabController,
        children: [
          const HomePage(),
          Ratings(),
          const Trips(),
          const ProfilePage(),
        ],
      ),
      // Make sure bottomNavigationBar is defined here
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.credit_card),
            label: "Ratings",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_tree),
            label: "Trips",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: "Profile",
          ),
        ],
        currentIndex: selectedIndex,
        // Uncomment the backgroundColor
        backgroundColor:
            Colors.green.shade300, // Try setting an explicit background color
        unselectedItemColor: Colors.white,
        selectedItemColor: Color.fromARGB(255, 6, 96, 199),
        showSelectedLabels: true,
        selectedLabelStyle: const TextStyle(
          fontSize: 12,
        ),
        type: BottomNavigationBarType.fixed,
        onTap: onBarItemClicked,
        elevation: 8, // Add elevation to make it more visible
      ),
    );
  }
}
