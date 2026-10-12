import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../widgets/section_card.dart';

/// Scrollable widget catalog shown on the Demo tab.
/// Each card shows the widget name, what it is and when to use it,
/// a live demo, and a short code sample.
class DemoGallery extends StatefulWidget {
  const DemoGallery({super.key});

  @override
  State<DemoGallery> createState() => _DemoGalleryState();
}

class _DemoGalleryState extends State<DemoGallery> {
  bool switchVal = true;
  bool? checkboxVal = true;
  int radioVal = 1;
  double sliderVal = 40;
  RangeValues rangeVal = const RangeValues(20, 80);
  Set<String> segmented = {'Day'};
  String dropdownVal = 'One';
  Set<String> filterChips = {'Music'};
  int navRailIndex = 0;
  int stepperIndex = 0;
  bool cupertinoSwitch = true;
  double cupertinoSlider = 50;
  bool boxBig = false;
  List<String> dismissItems = ['Swipe me away', 'Me too'];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        SectionCard(
          title: '1. Text — Text, RichText, SelectableText',
          description: 'Shows words on screen. Text is a plain single-style string. '
              'RichText mixes several styles in one paragraph (for example bold + color). '
              'SelectableText lets the user long-press to copy the text. '
              'Use these for every label, heading and paragraph.',
          code: r'''Text('Hello'),
RichText(
  text: TextSpan(children: [
    TextSpan(text: 'Bold '),
    TextSpan(text: 'red',
      style: TextStyle(fontWeight: FontWeight.bold)),
  ]),
),
SelectableText('Copy me'),''',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Plain Text widget'),
              RichText(
                text: const TextSpan(
                  style: TextStyle(color: Colors.black, fontSize: 16),
                  children: [
                    TextSpan(text: 'RichText with '),
                    TextSpan(
                        text: 'styled spans',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SelectableText('SelectableText (long-press to copy)'),
            ],
          ),
        ),
        SectionCard(
          title: '2. Buttons — Elevated, Filled, Tonal, Outlined, Text, Icon, FAB, Segmented',
          description: 'Buttons trigger actions. Elevated is the main action with a shadow; '
              'Filled is the main action flat; Tonal is a secondary action; '
              'Outlined and Text are low-emphasis actions. IconButton is an icon-only tap target. '
              'FloatingActionButton (FAB) is the round button floating over a screen for its single main action. '
              'SegmentedButton lets the user pick one of a few options, like Day / Week.',
          code: r'''ElevatedButton(onPressed: () {}, child: Text('Save')),
FilledButton.tonal(onPressed: () {}, child: Text('Draft')),
IconButton(onPressed: () {}, icon: Icon(Icons.delete)),
FloatingActionButton(onPressed: () {}, child: Icon(Icons.add)),''',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ElevatedButton(onPressed: () {}, child: const Text('Elevated')),
              FilledButton(onPressed: () {}, child: const Text('Filled')),
              FilledButton.tonal(
                  onPressed: () {}, child: const Text('Tonal')),
              OutlinedButton(onPressed: () {}, child: const Text('Outlined')),
              TextButton(onPressed: () {}, child: const Text('Text')),
              IconButton(onPressed: () {}, icon: const Icon(Icons.favorite)),
              FloatingActionButton.small(
                  onPressed: () {}, child: const Icon(Icons.add)),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'Day', label: Text('Day')),
                  ButtonSegment(value: 'Week', label: Text('Week')),
                ],
                selected: segmented,
                onSelectionChanged: (s) => setState(() => segmented = s),
              ),
            ],
          ),
        ),
        SectionCard(
          title: '3. Inputs — TextField, DropdownMenu, Slider, RangeSlider, Switch, Checkbox, Radio',
          description: 'Inputs collect choices from the user. TextField is a typed-text box for names, passwords and messages. '
              'DropdownMenu picks one item from a popup list. Slider drags to one number (volume, price); '
              'RangeSlider drags two handles for a min-max range. Switch is an on/off setting. '
              'Checkbox ticks several independent options and supports a third unknown state. '
              'Radio picks exactly one of several options.',
          code: r'''TextField(
  decoration: InputDecoration(labelText: 'Name')),
Slider(value: 40, max: 100, onChanged: (v) {}),
SwitchListTile(
  title: Text('Wi-Fi'), value: true, onChanged: (v) {}),
CheckboxListTile(
  title: Text('Email me'), value: false, onChanged: (v) {}),''',
          child: Column(
            children: [
              const TextField(
                  decoration: InputDecoration(
                      labelText: 'TextField', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              DropdownMenu<String>(
                initialSelection: dropdownVal,
                label: const Text('DropdownMenu'),
                dropdownMenuEntries: const [
                  DropdownMenuEntry(value: 'One', label: 'One'),
                  DropdownMenuEntry(value: 'Two', label: 'Two'),
                ],
                onSelected: (v) =>
                    setState(() => dropdownVal = v ?? dropdownVal),
              ),
              Slider(
                value: sliderVal,
                max: 100,
                label: sliderVal.round().toString(),
                onChanged: (v) => setState(() => sliderVal = v),
              ),
              RangeSlider(
                values: rangeVal,
                max: 100,
                labels: RangeLabels('${rangeVal.start.round()}',
                    '${rangeVal.end.round()}'),
                onChanged: (v) => setState(() => rangeVal = v),
              ),
              SwitchListTile(
                title: const Text('SwitchListTile'),
                value: switchVal,
                onChanged: (v) => setState(() => switchVal = v),
              ),
              CheckboxListTile(
                title: const Text('CheckboxListTile'),
                value: checkboxVal,
                tristate: true,
                onChanged: (v) => setState(() => checkboxVal = v),
              ),
              RadioListTile<int>(
                title: const Text('RadioListTile 1'),
                value: 1,
                groupValue: radioVal,
                onChanged: (v) => setState(() => radioVal = v ?? 1),
              ),
              RadioListTile<int>(
                title: const Text('RadioListTile 2'),
                value: 2,
                groupValue: radioVal,
                onChanged: (v) => setState(() => radioVal = v ?? 1),
              ),
            ],
          ),
        ),
        SectionCard(
          title: '4. Chips & badges — Chip, FilterChip, ChoiceChip, ActionChip, Badge, Tooltip',
          description: 'Chips are small labeled tokens. Chip is a static tag. FilterChip and ChoiceChip toggle on and off '
              'for filters like Music or Books. ActionChip runs a quick action. Badge shows a small count dot '
              'on top of an icon, for unread mail for example. Tooltip shows helper text on long-press. '
              'Use these for tags, filters and notification counts.',
          code: r'''FilterChip(
  label: Text('Music'), selected: true, onSelected: (v) {}),
ActionChip(label: Text('Share'), onPressed: () {}),
Badge(label: Text('3'), child: Icon(Icons.mail)),
Tooltip(message: 'More info', child: Icon(Icons.info)),''',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Chip(label: Text('Chip'), avatar: Icon(Icons.tag)),
              FilterChip(
                label: const Text('FilterChip'),
                selected: filterChips.contains('Music'),
                onSelected: (v) => setState(() {
                  v ? filterChips.add('Music') : filterChips.remove('Music');
                }),
              ),
              ChoiceChip(
                label: const Text('ChoiceChip'),
                selected: filterChips.contains('Books'),
                onSelected: (v) => setState(() {
                  v ? filterChips.add('Books') : filterChips.remove('Books');
                }),
              ),
              ActionChip(
                  label: const Text('ActionChip'),
                  avatar: const Icon(Icons.bolt, size: 16),
                  onPressed: () {}),
              const Badge(label: Text('3'), child: Icon(Icons.mail_outline)),
              const Tooltip(
                  message: 'Tooltip', child: Icon(Icons.info_outline)),
            ],
          ),
        ),
        SectionCard(
          title: '5. Progress — CircularProgressIndicator, LinearProgressIndicator',
          description: 'Progress widgets show that work is happening. CircularProgressIndicator is the round spinner '
              'for waits of unknown length. LinearProgressIndicator is the horizontal bar; pass it a value '
              'from 0.0 to 1.0 to show exact progress like a download at 60 percent. '
              'Use these for loading, saving and uploading states.',
          code: r'''CircularProgressIndicator(), // unknown wait
LinearProgressIndicator(value: 0.6), // 60% done''',
          child: const Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              LinearProgressIndicator(),
            ],
          ),
        ),
        SectionCard(
          title: '6. Cards & tiles — Card, ListTile, ExpansionTile, Divider, CircleAvatar, Image',
          description: 'Cards group related content in a rounded box. ListTile is the standard settings-style row: '
              'a leading icon, a title, an optional subtitle, and a trailing arrow. '
              'ExpansionTile is a ListTile that expands to reveal hidden children. Divider is a thin separator line. '
              'CircleAvatar is the round user picture. Image shows pictures from files, assets or the internet. '
              'Use these for lists, contacts, settings and feeds.',
          code: r'''Card(
  child: ListTile(
    leading: CircleAvatar(child: Icon(Icons.person)),
    title: Text('Ada'),
    subtitle: Text('Admin'),
    trailing: Icon(Icons.chevron_right),
    onTap: () {},
  ),
),
Image.network('https://example.com/photo.png'),''',
          child: Column(
            children: [
              const Card(
                child: ListTile(
                  leading: CircleAvatar(child: Icon(Icons.person)),
                  title: Text('ListTile inside Card'),
                  subtitle: Text('leading / title / subtitle / trailing'),
                  trailing: Icon(Icons.chevron_right),
                ),
              ),
              const ExpansionTile(
                leading: Icon(Icons.expand_more),
                title: Text('ExpansionTile (tap to expand)'),
                children: [ListTile(title: Text('Hidden child tile'))],
              ),
              const Divider(),
              Row(
                children: [
                  const FlutterLogo(size: 48),
                  const SizedBox(width: 12),
                  Container(
                    width: 48,
                    height: 48,
                    color: Colors.indigo.shade100,
                    child: const Icon(Icons.image_outlined),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                      child: Text('FlutterLogo + Image box + Divider above')),
                ],
              ),
            ],
          ),
        ),
        SectionCard(
          title: '7. Popups — AlertDialog, BottomSheet, SnackBar, DatePicker, TimePicker, DateRangePicker, MenuAnchor',
          description: 'Popups appear above the current screen. AlertDialog asks a question or confirms an action. '
              'BottomSheet slides a panel up from the bottom for extra options. SnackBar shows a brief message '
              'at the bottom, like Saved. DatePicker, TimePicker and DateRangePicker open the system clock and '
              'calendar pickers. MenuAnchor attaches a dropdown menu to a button. '
              'Use these for confirmations, feedback messages and picking dates.',
          code: r'''showDialog(context: context, builder: (_) => AlertDialog(
  title: Text('Delete?'),
  actions: [
    TextButton(onPressed: () {}, child: Text('Cancel')),
    FilledButton(onPressed: () {}, child: Text('Delete')),
  ],
));
ScaffoldMessenger.of(context)
  .showSnackBar(SnackBar(content: Text('Saved')));
showDatePicker(context: context,
  firstDate: DateTime(2020), lastDate: DateTime(2030));''',
          child: Builder(
            builder: (ctx) => Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () => showDialog(
                    context: ctx,
                    builder: (_) => AlertDialog(
                      title: const Text('AlertDialog'),
                      content: const Text('This is an AlertDialog.'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Close')),
                      ],
                    ),
                  ),
                  child: const Text('Dialog'),
                ),
                OutlinedButton(
                  onPressed: () => showModalBottomSheet(
                    context: ctx,
                    builder: (_) => const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('ModalBottomSheet'),
                    ),
                  ),
                  child: const Text('BottomSheet'),
                ),
                OutlinedButton(
                  onPressed: () => ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('SnackBar'))),
                  child: const Text('SnackBar'),
                ),
                OutlinedButton(
                  onPressed: () => showDatePicker(
                    context: ctx,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  ),
                  child: const Text('DatePicker'),
                ),
                OutlinedButton(
                  onPressed: () => showTimePicker(
                      context: ctx, initialTime: TimeOfDay.now()),
                  child: const Text('TimePicker'),
                ),
                OutlinedButton(
                  onPressed: () => showDateRangePicker(
                    context: ctx,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  ),
                  child: const Text('DateRangePicker'),
                ),
                MenuAnchor(
                  menuChildren: [
                    MenuItemButton(
                        onPressed: () {}, child: const Text('MenuItem 1')),
                    MenuItemButton(
                        onPressed: () {}, child: const Text('MenuItem 2')),
                  ],
                  builder: (context, controller, child) => OutlinedButton(
                    onPressed: () => controller.isOpen
                        ? controller.close()
                        : controller.open(),
                    child: const Text('MenuAnchor'),
                  ),
                ),
              ],
            ),
          ),
        ),
        SectionCard(
          title: '8. Layout — GridView, Wrap, Stack, DataTable',
          description: 'Layout widgets arrange other widgets. GridView lays items out in a grid of rows and columns. '
              'Wrap flows chips across lines instead of overflowing. Stack layers widgets on top of each other, '
              'with Positioned pinning a child to a corner. DataTable renders spreadsheet-like rows and columns. '
              'Use these to structure photo grids, tag rows, overlays and tables.',
          code: r'''GridView.count(crossAxisCount: 4, children: [...]),
Wrap(spacing: 8, children: [Chip(label: Text('A'))]),
Stack(children: [
  Container(color: Colors.blue),
  Positioned(top: 8, left: 8, child: Text('On top')),
]),''',
          child: Column(
            children: [
              SizedBox(
                height: 120,
                child: GridView.count(
                  crossAxisCount: 4,
                  physics: const NeverScrollableScrollPhysics(),
                  children: List.generate(
                    4,
                    (i) => Card(child: Center(child: Text('G${i + 1}'))),
                  ),
                ),
              ),
              const Wrap(
                spacing: 8,
                children: [
                  Chip(label: Text('Wrap')),
                  Chip(label: Text('flows')),
                  Chip(label: Text('chips')),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 80,
                child: Stack(
                  children: [
                    Container(color: Colors.indigo.shade100),
                    const Positioned(
                      top: 8,
                      left: 8,
                      child: Text('Stack + Positioned'),
                    ),
                    const Positioned(
                      bottom: 8,
                      right: 8,
                      child: Icon(Icons.layers_outlined),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              DataTable(
                columns: const [
                  DataColumn(label: Text('DataTable')),
                  DataColumn(label: Text('Value')),
                ],
                rows: const [
                  DataRow(
                      cells: [DataCell(Text('Row 1')), DataCell(Text('A'))]),
                  DataRow(
                      cells: [DataCell(Text('Row 2')), DataCell(Text('B'))]),
                ],
              ),
            ],
          ),
        ),
        SectionCard(
          title: '9. Navigation — Drawer, TabBar, NavigationRail, Stepper, CarouselView',
          description: 'Navigation widgets move the user between content. The Drawer (here a NavigationDrawer) is the side menu '
              'that slides in from the left. TabBar plus TabBarView gives swipeable top tabs and needs a '
              'DefaultTabController. NavigationRail is a slim side tab bar for wide screens like tablets. '
              'Stepper walks the user through numbered steps, like checkout. CarouselView is a swipeable row of cards.',
          code: r'''DefaultTabController(
  length: 2,
  child: Column(children: [
    TabBar(tabs: [Tab(text: 'Chats'), Tab(text: 'Calls')]),
    Expanded(child: TabBarView(
      children: [ChatsPage(), CallsPage()])),
  ]),
),
Scaffold(
  drawer: NavigationDrawer(children: [...]),
  bottomNavigationBar: NavigationBar(destinations: [...]),
),''',
          child: Column(
            children: [
              Builder(
                builder: (ctx) => OutlinedButton(
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                  child: const Text('Open Drawer (NavigationDrawer)'),
                ),
              ),
              const SizedBox(height: 8),
              DefaultTabController(
                length: 3,
                child: Column(
                  children: [
                    const TabBar(
                      tabs: [
                        Tab(text: 'TabBar 1'),
                        Tab(text: 'TabBar 2'),
                        Tab(text: 'TabBar 3'),
                      ],
                    ),
                    SizedBox(
                      height: 100,
                      child: TabBarView(
                        children: [
                          Center(child: Text('TabBarView page 1')),
                          Center(child: Text('TabBarView page 2')),
                          Center(child: Text('TabBarView page 3')),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 190,
                child: Row(
                  children: [
                    NavigationRail(
                      selectedIndex: navRailIndex,
                      onDestinationSelected: (i) =>
                          setState(() => navRailIndex = i),
                      labelType: NavigationRailLabelType.all,
                      destinations: const [
                        NavigationRailDestination(
                            icon: Icon(Icons.home_outlined),
                            label: Text('Rail 1')),
                        NavigationRailDestination(
                            icon: Icon(Icons.star_outline),
                            label: Text('Rail 2')),
                      ],
                    ),
                    const VerticalDivider(),
                    Expanded(
                        child:
                            Text('NavigationRail — page ${navRailIndex + 1}')),
                  ],
                ),
              ),
              SizedBox(
                height: 170,
                child: Stepper(
                  currentStep: stepperIndex,
                  onStepTapped: (i) => setState(() => stepperIndex = i),
                  onStepContinue: () =>
                      setState(() => stepperIndex = (stepperIndex + 1) % 3),
                  onStepCancel: () =>
                      setState(() => stepperIndex = (stepperIndex - 1) % 3),
                  steps: const [
                    Step(
                        title: Text('Stepper 1'),
                        content: Text('First step')),
                    Step(
                        title: Text('Stepper 2'),
                        content: Text('Second step')),
                    Step(
                        title: Text('Stepper 3'),
                        content: Text('Third step')),
                  ],
                ),
              ),
              SizedBox(
                height: 150,
                child: CarouselView(
                  itemExtent: 140,
                  children: List.generate(
                    5,
                    (i) => Card(
                        color: Colors.indigo.shade100,
                        child: Center(child: Text('Carousel ${i + 1}'))),
                  ),
                ),
              ),
            ],
          ),
        ),
        SectionCard(
          title: '10. iOS style (Cupertino) — CupertinoButton, CupertinoSwitch, CupertinoSlider, CupertinoPicker, CupertinoActivityIndicator',
          description: 'Cupertino widgets copy the Apple iOS look instead of Google Material. '
              'CupertinoButton is the iOS text button, CupertinoSwitch and CupertinoSlider are the iOS toggle and slider, '
              'CupertinoPicker is the iOS scroll-wheel picker, CupertinoActivityIndicator is the iOS spinner, '
              'and CupertinoAlertDialog is the iOS popup. Use these when the app must feel native on iPhone.',
          code: r'''CupertinoButton(onPressed: () {}, child: Text('Save')),
CupertinoSwitch(value: true, onChanged: (v) {}),
CupertinoSlider(value: 50, max: 100, onChanged: (v) {}),
CupertinoActivityIndicator(),''',
          child: Column(
            children: [
              Row(
                children: [
                  CupertinoButton(
                    onPressed: () {},
                    child: const Text('CupertinoButton'),
                  ),
                  const CupertinoActivityIndicator(),
                ],
              ),
              Row(
                children: [
                  const Text('CupertinoSwitch'),
                  CupertinoSwitch(
                    value: cupertinoSwitch,
                    onChanged: (v) => setState(() => cupertinoSwitch = v),
                  ),
                ],
              ),
              SizedBox(
                width: double.infinity,
                child: CupertinoSlider(
                  value: cupertinoSlider,
                  max: 100,
                  onChanged: (v) => setState(() => cupertinoSlider = v),
                ),
              ),
              Builder(
                builder: (ctx) => CupertinoButton(
                  onPressed: () => showCupertinoDialog(
                    context: ctx,
                    builder: (_) => CupertinoAlertDialog(
                      title: const Text('CupertinoAlertDialog'),
                      content: const Text('iOS-style dialog.'),
                      actions: [
                        CupertinoDialogAction(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  ),
                  child: const Text('CupertinoAlertDialog'),
                ),
              ),
              SizedBox(
                height: 120,
                child: CupertinoPicker(
                  itemExtent: 32,
                  onSelectedItemChanged: (_) {},
                  children: const [
                    Text('CupertinoPicker 1'),
                    Text('CupertinoPicker 2'),
                    Text('CupertinoPicker 3'),
                  ],
                ),
              ),
            ],
          ),
        ),
        SectionCard(
          title: '11. Motion & touch — AnimatedContainer, Dismissible, GestureDetector',
          description: 'Motion widgets react to touch. AnimatedContainer smoothly animates its size, color or padding '
              'whenever you change the values with setState — just tap the box below. Dismissible lets the user '
              'swipe a row away to delete it, like an email. GestureDetector detects taps, double-taps and drags '
              'on any widget. Use these for delightful interactive lists and animations.',
          code: r'''AnimatedContainer(
  duration: Duration(milliseconds: 300),
  width: big ? 200 : 100,
  color: big ? Colors.indigo : Colors.teal,
),
Dismissible(
  key: ValueKey(item),
  onDismissed: (_) => items.remove(item),
  child: ListTile(title: Text(item)),
),
GestureDetector(onTap: () {}, child: Icon(Icons.star)),''',
          child: Column(
            children: [
              GestureDetector(
                onTap: () => setState(() => boxBig = !boxBig),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: boxBig ? 200 : 100,
                  height: boxBig ? 100 : 60,
                  color: boxBig ? Colors.indigo : Colors.teal,
                  alignment: Alignment.center,
                  child: const Text('Tap me\n(AnimatedContainer)',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white)),
                ),
              ),
              const SizedBox(height: 8),
              ...dismissItems.map(
                (t) => Dismissible(
                  key: ValueKey(t),
                  background: Container(
                    color: Colors.red.shade200,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 16),
                    child: const Icon(Icons.delete_outline),
                  ),
                  onDismissed: (_) => setState(() => dismissItems.remove(t)),
                  child: ListTile(title: Text('Dismissible: $t')),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
