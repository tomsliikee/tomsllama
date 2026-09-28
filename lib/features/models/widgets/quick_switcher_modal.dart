import 'package:flutter/material.dart';
import '../../../core/models/conversation.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_typography.dart';

class QuickSwitcherModal extends StatefulWidget {
  final List<Conversation> conversations;
  final ValueChanged<String> onSelect;

  const QuickSwitcherModal({
    super.key,
    required this.conversations,
    required this.onSelect,
  });

  @override
  State<QuickSwitcherModal> createState() => _QuickSwitcherModalState();
}

class _QuickSwitcherModalState extends State<QuickSwitcherModal> {
  final TextEditingController _controller = TextEditingController();
  List<Conversation> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.conversations;
  }

  void _filter(String query) {
    if (query.isEmpty) {
      setState(() => _filtered = widget.conversations);
    } else {
      setState(() {
        _filtered = widget.conversations
            .where((c) => c.title.toLowerCase().contains(query.toLowerCase()))
            .toList();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;

    return Dialog(
      backgroundColor: appColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Container(
        width: 600,
        height: 400,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Search Input
            TextField(
              controller: _controller,
              onChanged: _filter,
              autofocus: true,
              style: AppTypography.uiControl.copyWith(
                color: appColors.textPrimary,
                fontSize: 18.0,
              ),
              decoration: InputDecoration(
                hintText: 'Search chats... (Type to filter)',
                hintStyle: TextStyle(color: appColors.textSecondary),
                prefixIcon: Icon(Icons.search, color: appColors.textSecondary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide(color: appColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide(color: appColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide(color: appColors.accent),
                ),
              ),
            ),
            const SizedBox(height: 16.0),
            
            // Results
            Expanded(
              child: ListView.builder(
                itemCount: _filtered.length,
                itemBuilder: (context, index) {
                  final c = _filtered[index];
                  return ListTile(
                    title: Text(
                      c.title.isEmpty ? 'New Chat' : c.title,
                      style: AppTypography.uiControl.copyWith(color: appColors.textPrimary),
                    ),
                    subtitle: Text(
                      c.createdAt.toIso8601String().substring(0, 10),
                      style: AppTypography.uiControl.copyWith(color: appColors.textSecondary, fontSize: 12.0),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      widget.onSelect(c.id);
                    },
                    hoverColor: appColors.accentSubtle,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
