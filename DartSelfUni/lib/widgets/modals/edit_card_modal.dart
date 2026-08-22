import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/card_model.dart';
import '../../providers/deck_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class EditCardModal extends StatefulWidget {
  final String deckId;
  final Flashcard card;

  const EditCardModal({
    super.key,
    required this.deckId,
    required this.card,
  });

  @override
  State<EditCardModal> createState() => _EditCardModalState();
}

class _EditCardModalState extends State<EditCardModal> {
  late TextEditingController _frontController;
  late TextEditingController _backController;
  late TextEditingController _codeController;
  late CardType _selectedType;
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    _frontController = TextEditingController(text: widget.card.front);
    _backController = TextEditingController(text: widget.card.back);
    _codeController = TextEditingController(text: widget.card.codeSnippet ?? '');
    _selectedType = widget.card.type;
    _imageUrl = widget.card.imageUrl;
  }

  @override
  void dispose() {
    _frontController.dispose();
    _backController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _imageUrl = image.path;
      });
    }
  }

  void _save() {
    if (_frontController.text.trim().isEmpty) return;

    final updatedCard = widget.card.copyWith(
      front: _frontController.text,
      back: _backController.text,
      codeSnippet: _codeController.text.isNotEmpty ? _codeController.text : null,
      imageUrl: _imageUrl,
      type: _selectedType,
    );

    context.read<DeckProvider>().updateCard(widget.deckId, updatedCard);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Edit Card',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Card Type / Archetype',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: CardType.values.map((type) {
                  final config = ArchetypeConfig.configs[type]!;
                  final isSelected = _selectedType == type;

                  return InkWell(
                    onTap: () => setState(() => _selectedType = type),
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? config.backgroundColor : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? config.color : AppColors.border,
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: isSelected
                            ? [BoxShadow(color: config.color.withValues(alpha: 0.15), blurRadius: 6, offset: const Offset(0, 2))]
                            : [],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(config.icon, size: 16, color: isSelected ? config.color : AppColors.textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            config.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? config.color : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 6),
              Text(
                ArchetypeConfig.configs[_selectedType]?.description ?? '',
                style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: ArchetypeConfig.configs[_selectedType]?.color ?? AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _frontController,
                decoration: const InputDecoration(
                  labelText: 'Front (Question / Context)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _backController,
                decoration: const InputDecoration(
                  labelText: 'Back (Answer / Explanation)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: 'Code Snippet (Optional)',
                  border: OutlineInputBorder(),
                  hintText: 'e.g. function() { ... }',
                ),
                maxLines: 6,
                style: const TextStyle(fontFamily: 'Consolas'),
              ),
              const SizedBox(height: 16),
              if (_imageUrl != null)
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _imageUrl!.startsWith('http')
                            ? Image.network(_imageUrl!, fit: BoxFit.cover)
                            : Image.file(File(_imageUrl!), fit: BoxFit.cover),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () => setState(() => _imageUrl = null),
                    ),
                  ],
                ),
              if (_imageUrl == null)
                OutlinedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.image),
                  label: const Text('Attach Image'),
                ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Save Changes'),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
