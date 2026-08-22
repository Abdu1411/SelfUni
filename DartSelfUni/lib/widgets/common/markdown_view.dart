import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:markdown/markdown.dart' as md;
import '../../core/constants/app_colors.dart';

/// Inline Math Syntax Parser for $math$ and \(math\)
class InlineMathSyntax extends md.InlineSyntax {
  InlineMathSyntax() : super(r'\$([^\$]+)\$|\\\((.*?)\\\)');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final formula = match.group(1) ?? match.group(2) ?? '';
    final el = md.Element('latex_inline', [md.Text(formula)]);
    parser.addNode(el);
    return true;
  }
}

/// Display Math Syntax Parser for $$math$$ and \[math\]
class BlockMathSyntax extends md.BlockSyntax {
  @override
  RegExp get pattern => RegExp(r'^\$\$(.*?)\$\$$|^\\\[(.*?)\\\]$', multiLine: true, dotAll: true);

  const BlockMathSyntax();

  @override
  md.Node parse(md.BlockParser parser) {
    final match = pattern.firstMatch(parser.current.content)!;
    final formula = match.group(1) ?? match.group(2) ?? parser.current.content.replaceAll('\$\$', '').replaceAll(r'\[', '').replaceAll(r'\]', '');
    parser.advance();
    return md.Element('latex_block', [md.Text(formula.trim())]);
  }
}

/// Builder for Inline Math ($math$)
class InlineMathBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final formula = element.textContent;
    try {
      return Math.tex(
        formula,
        textStyle: preferredStyle?.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold) ?? const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14),
        onErrorFallback: (err) => Text('\$$formula\$', style: const TextStyle(color: AppColors.error, fontFamily: 'Consolas, monospace')),
      );
    } catch (_) {
      return Text('\$$formula\$', style: const TextStyle(fontFamily: 'Consolas, monospace'));
    }
  }
}

/// Builder for Display Math ($$math$$)
class BlockMathBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final formula = element.textContent;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Center(
          child: Math.tex(
            formula,
            textStyle: const TextStyle(fontSize: 16.5, color: Color(0xFF0F172A)),
            onErrorFallback: (err) => Text('\$\$\n$formula\n\$\$', style: const TextStyle(color: AppColors.error, fontFamily: 'Consolas, monospace')),
          ),
        ),
      ),
    );
  }
}

/// Builder for Callouts and Alert Blockquotes ([!NOTE], [!TIP], [!IMPORTANT], [!WARNING], [!CAUTION])
class CalloutBlockquoteBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final rawText = element.textContent.trim();
    
    // Alert configurations
    Color borderColor = AppColors.primary;
    Color bgColor = const Color(0xFFEFF6FF); // blue-50
    IconData icon = Icons.info_outline;
    String alertTitle = 'Note';
    String content = rawText;

    if (rawText.startsWith('[!NOTE]') || rawText.startsWith('NOTE:')) {
      borderColor = const Color(0xFF2563EB); // blue
      bgColor = const Color(0xFFEFF6FF);
      icon = Icons.info_outline;
      alertTitle = 'Note';
      content = rawText.replaceFirst(RegExp(r'^(\[!NOTE\]|NOTE:)\s*'), '');
    } else if (rawText.startsWith('[!TIP]') || rawText.startsWith('TIP:')) {
      borderColor = const Color(0xFF059669); // green
      bgColor = const Color(0xFFECFDF5);
      icon = Icons.lightbulb_outline;
      alertTitle = 'Tip';
      content = rawText.replaceFirst(RegExp(r'^(\[!TIP\]|TIP:)\s*'), '');
    } else if (rawText.startsWith('[!IMPORTANT]') || rawText.startsWith('IMPORTANT:')) {
      borderColor = const Color(0xFF7C3AED); // purple
      bgColor = const Color(0xFFF5F3FF);
      icon = Icons.stars_rounded;
      alertTitle = 'Important';
      content = rawText.replaceFirst(RegExp(r'^(\[!IMPORTANT\]|IMPORTANT:)\s*'), '');
    } else if (rawText.startsWith('[!WARNING]') || rawText.startsWith('WARNING:')) {
      borderColor = const Color(0xFFD97706); // amber
      bgColor = const Color(0xFFFFFBEB);
      icon = Icons.warning_amber_rounded;
      alertTitle = 'Warning';
      content = rawText.replaceFirst(RegExp(r'^(\[!WARNING\]|WARNING:)\s*'), '');
    } else if (rawText.startsWith('[!CAUTION]') || rawText.startsWith('CAUTION:')) {
      borderColor = const Color(0xFFDC2626); // red
      bgColor = const Color(0xFFFEF2F2);
      icon = Icons.error_outline;
      alertTitle = 'Caution';
      content = rawText.replaceFirst(RegExp(r'^(\[!CAUTION\]|CAUTION:)\s*'), '');
    } else {
      // Standard blockquote
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
          border: Border(left: BorderSide(color: AppColors.primary.withValues(alpha: 0.6), width: 4)),
        ),
        child: Text(
          rawText,
          style: const TextStyle(
            fontSize: 15,
            fontStyle: FontStyle.italic,
            color: Color(0xFF475569),
            height: 1.6,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: borderColor),
              const SizedBox(width: 8),
              Text(
                alertTitle.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: borderColor,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content.trim(),
            style: const TextStyle(
              fontSize: 14.5,
              color: Color(0xFF1E293B),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom Code Block Builder with IDE Theme & Syntax Highlighting
class CodeBlockBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final code = element.textContent.trimRight();
    final infoString = element.attributes['class'] ?? '';
    String language = 'dart';

    if (infoString.startsWith('language-')) {
      language = infoString.replaceFirst('language-', '').toLowerCase();
    }

    return CodeSnippetWidget(code: code, language: language);
  }
}

class CodeSnippetWidget extends StatefulWidget {
  final String code;
  final String language;

  const CodeSnippetWidget({super.key, required this.code, required this.language});

  @override
  State<CodeSnippetWidget> createState() => _CodeSnippetWidgetState();
}

class _CodeSnippetWidgetState extends State<CodeSnippetWidget> {
  bool _copied = false;

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: widget.code));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Use full available width — let the parent constrain it.
    // On very wide screens cap at a comfortable reading width.
    final snippetWidth = screenWidth < 700
        ? screenWidth * 0.94
        : (screenWidth * 0.55).clamp(300.0, 860.0);

    final dynamicFontSize = (screenWidth * 0.011).clamp(11.5, 17.5);
    final headerFontSize = (screenWidth * 0.008).clamp(9.5, 12.0);

    return Container(
      width: snippetWidth,
      margin: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A), // slate-900 IDE background
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155), width: 1.2), // slate-700
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Bar with Window Controls & Copy Button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B), // slate-800
                borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
                border: Border(bottom: BorderSide(color: Color(0xFF334155))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFFF59E0B), shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                      const SizedBox(width: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Text(
                          widget.language.toUpperCase(),
                          style: TextStyle(
                            fontFamily: 'Consolas, monospace',
                            fontSize: headerFontSize,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF38BDF8), // sky-400
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: _copyCode,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF334155),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_copied ? Icons.check : Icons.copy, size: 13, color: _copied ? const Color(0xFF34D399) : Colors.white70),
                          const SizedBox(width: 6),
                          Text(
                            _copied ? 'Copied!' : 'Copy Code',
                            style: TextStyle(
                              fontSize: headerFontSize,
                              fontWeight: FontWeight.bold,
                              color: _copied ? const Color(0xFF34D399) : Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Code Syntax Highlight Area
            Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: HighlightView(
                  widget.code,
                  language: widget.language,
                  theme: const {
                    'root': TextStyle(color: Color(0xFFF8FAFC), backgroundColor: Colors.transparent),
                    'keyword': TextStyle(color: Color(0xFFF472B6), fontWeight: FontWeight.bold),
                    'selector-tag': TextStyle(color: Color(0xFFF472B6), fontWeight: FontWeight.bold),
                    'built_in': TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold),
                    'type': TextStyle(color: Color(0xFFFBBF24), fontWeight: FontWeight.bold),
                    'literal': TextStyle(color: Color(0xFFFB923C)),
                    'number': TextStyle(color: Color(0xFFFB923C)),
                    'string': TextStyle(color: Color(0xFFA3E635)),
                    'comment': TextStyle(color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
                    'doctag': TextStyle(color: Color(0xFFCBD5E1), fontStyle: FontStyle.italic),
                    'function': TextStyle(color: Color(0xFF60A5FA), fontWeight: FontWeight.bold),
                    'title': TextStyle(color: Color(0xFF60A5FA), fontWeight: FontWeight.bold),
                    'params': TextStyle(color: Color(0xFFE2E8F0)),
                    'symbol': TextStyle(color: Color(0xFFC084FC)),
                    'class': TextStyle(color: Color(0xFFFBBF24)),
                    'variable': TextStyle(color: Color(0xFFF8FAFC)),
                  },
                  padding: EdgeInsets.zero,
                  textStyle: TextStyle(
                    fontFamily: 'Consolas, Courier New, monospace',
                    fontSize: dynamicFontSize,
                    height: 1.65,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
  }
}

/// Horizontal Rule Divider Builder
class HrBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 24),
      height: 1.5,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE2E8F0), Color(0xFFCBD5E1), Color(0xFFE2E8F0)],
        ),
      ),
    );
  }
}

class MarkdownView extends StatelessWidget {
  final String data;
  final bool isSelectable;

  const MarkdownView({
    super.key,
    required this.data,
    this.isSelectable = true,
  });

  @override
  Widget build(BuildContext context) {
    if (data.trim().isEmpty) {
      return const Text('*No content*', style: TextStyle(fontStyle: FontStyle.italic, color: AppColors.textSecondary));
    }

    final cleanedData = _sanitizeMarkdown(data);

    return MarkdownBody(
      data: cleanedData,
      selectable: isSelectable,
      extensionSet: md.ExtensionSet.gitHubFlavored,
      onTapLink: (text, href, title) async {
        if (href != null && href.isNotEmpty) {
          final uri = Uri.parse(href);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
          }
        }
      },
      inlineSyntaxes: [InlineMathSyntax()],
      blockSyntaxes: const [BlockMathSyntax()],
      builders: {
        'latex_inline': InlineMathBuilder(),
        'latex_block': BlockMathBuilder(),
        'code': CodeBlockBuilder(),
        'blockquote': CalloutBlockquoteBuilder(),
        'hr': HrBuilder(),
      },
      styleSheet: MarkdownStyleSheet(
        p: const TextStyle(
          fontSize: 16,
          color: Color(0xFF334155), // slate-700
          height: 1.75,
          letterSpacing: 0.2,
        ),
        a: const TextStyle(
          fontSize: 16,
          color: Color(0xFF2563EB),
          decoration: TextDecoration.underline,
          fontWeight: FontWeight.bold,
        ),
        h1: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w900,
          color: Color(0xFF0F172A),
          height: 1.35,
          letterSpacing: -0.5,
        ),
        h2: const TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.bold,
          color: Color(0xFF0F172A),
          height: 1.35,
          letterSpacing: -0.3,
        ),
        h3: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1E293B),
          height: 1.35,
        ),
        h4: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Color(0xFF334155),
        ),
        listBullet: const TextStyle(
          color: AppColors.primary,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        listIndent: 28,
        tableBorder: TableBorder.all(
          color: const Color(0xFFE2E8F0),
          width: 1.2,
          borderRadius: BorderRadius.circular(8),
        ),
        tableHead: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Color(0xFF0F172A),
        ),
        tableBody: const TextStyle(
          fontSize: 14,
          color: Color(0xFF334155),
          height: 1.5,
        ),
        tableHeadAlign: TextAlign.center,
        tableCellsPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        tableColumnWidth: const FlexColumnWidth(),
        code: const TextStyle(
          fontFamily: 'Consolas, Courier New, monospace',
          backgroundColor: Color(0xFFF1F5F9), // slate-100
          color: Color(0xFF0284C7), // sky-600
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        codeblockDecoration: const BoxDecoration(
          color: Colors.transparent,
        ),
        codeblockPadding: EdgeInsets.zero,
        blockquote: const TextStyle(
          fontSize: 15,
          color: Color(0xFF475569),
          fontStyle: FontStyle.italic,
          height: 1.6,
        ),
        blockquoteDecoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
          border: const Border(left: BorderSide(color: Color(0xFF3B82F6), width: 4)),
        ),
        horizontalRuleDecoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1.5)),
        ),
      ),
    );
  }
}

/// Pre-processes raw markdown to fix common AI formatting issues before rendering.
String _sanitizeMarkdown(String raw) {
  // 1. Replace <br> tags with newlines
  String out = raw.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');

  // 2. Strip fenced code blocks from inside table rows.
  // Tables in markdown are lines starting with |. We detect table rows that
  // contain ``` and replace the whole code block with inline code instead.
  final lines = out.split('\n');
  final result = <String>[];
  bool insideTableCodeFence = false;
  final fenceBuffer = StringBuffer();
  String fenceLang = '';

  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    final trimmed = line.trim();

    if (insideTableCodeFence) {
      if (trimmed.startsWith('```')) {
        // End of the code fence that was inside a table — emit inline code
        final code = fenceBuffer.toString().trim();
        if (result.isNotEmpty) {
          result[result.length - 1] = result.last.replaceAll(
            RegExp(r'`{2,}'),
            '`$code`',
          );
        }
        insideTableCodeFence = false;
        fenceBuffer.clear();
        fenceLang = '';
      } else {
        if (fenceBuffer.isNotEmpty) fenceBuffer.write(' ');
        fenceBuffer.write(trimmed);
      }
      continue;
    }

    // Detect a table row that contains a fenced code block opening
    if (trimmed.startsWith('|') && trimmed.contains('```')) {
      final fenceMatch = RegExp(r'```(\w*)').firstMatch(trimmed);
      if (fenceMatch != null) {
        fenceLang = fenceMatch.group(1) ?? '';
        final afterFenceStart = trimmed.indexOf('```') + 3 + fenceLang.length;
        final rest = trimmed.substring(afterFenceStart);
        if (rest.contains('```')) {
          // Self-contained on one line: ```lang code``` → `code`
          final inlineCode = rest.split('```').first.trim();
          result.add(trimmed.replaceAll(
            RegExp(r'```\w*[^`]*```'),
            inlineCode.isNotEmpty ? '`$inlineCode`' : '',
          ));
        } else {
          // Multi-line fence opening inside a table cell — buffer it
          insideTableCodeFence = true;
          fenceBuffer.clear();
          fenceLang = fenceLang;
          // Keep the table row but strip the opening fence marker
          result.add(trimmed.replaceAll(RegExp(r'```\w*'), ''));
        }
        continue;
      }
    }

    result.add(line);
  }

  return result.join('\n');
}
