import 'package:flutter/material.dart';

class DoorBell extends StatefulWidget {
  const DoorBell({super.key});

  @override
  State<DoorBell> createState() => DoorBellState();
}

class DoorBellState extends State<DoorBell> {
  @override
  Widget build(BuildContext context) {
    final ButtonStyle buttonStyle = ElevatedButton.styleFrom(
      textStyle: const TextStyle(fontSize: 48),
      backgroundColor: Colors.green.shade900,
      foregroundColor: Colors.white,
      padding: EdgeInsets.all(24.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18.0),
        side: BorderSide(width: 4.0, color: Colors.green.shade800),
      ),
    );

    // ) Center(child: Text('Doorbell', style: theme.textTheme.titleLarge)),
    return Card(
      shadowColor: Colors.transparent,
      margin: const EdgeInsets.all(8.0),
      child: SizedBox.expand(
        child: Row(
          children: [
            Container(
              margin: const EdgeInsets.all(32.0),
              decoration: BoxDecoration(
                border: Border.all(width: 2.0, color: Colors.green.shade900),
              ),
              width: 480.0,
              height: 360.0,
              child: Center(child: Icon(Icons.camera_outdoor, size: 120)),
            ),
            Container(
              margin: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ElevatedButton(
                    style: buttonStyle,
                    child: Text('Open door'),
                    onPressed: () {},
                  ),
                  const SizedBox(
                    height: 20,
                    child: Divider(
                      thickness: 4,
                      height: 40,
                      color: Colors.blue,
                      indent: 20,
                      endIndent: 0,
                    ),
                  ),
                  //Text('Last door bell rings'),
                  Table(children: []),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
