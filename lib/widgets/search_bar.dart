import 'package:flutter/material.dart';

class SearchBar extends StatelessWidget {
  const SearchBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.search,
            color: Colors.black), // Search icon outside the black box
        SizedBox(width: 8.0), // Add some spacing
        Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(5.0),
            ),
            child: Text(
              'Search',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Roboto',
                fontSize: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
