import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:markdown/markdown.dart' as md;
import '../../core/constants/app_colors.dart';
import '../../core/services/ai_service.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:provider/provider.dart';
import '../../providers/deck_provider.dart';

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

Color _parseHexColor(String hex, Color defaultColor) {
  try {
    var hexColor = hex.replaceAll('#', '').trim();
    if (hexColor.length == 6) {
      hexColor = 'FF$hexColor';
    }
    if (hexColor.length == 8) {
      return Color(int.parse(hexColor, radix: 16));
    }
  } catch (_) {}
  return defaultColor;
}

Map<String, Style> getHtmlStyleSheet(BuildContext context, {bool isArabic = false, bool isRtl = false}) {
  DeckProvider? provider;
  try {
    provider = Provider.of<DeckProvider>(context, listen: false);
  } catch (_) {}
  final custom = provider?.customThemeStyles ?? {};

  final bg = _parseHexColor(custom['bg'] ?? '#ffffff', const Color(0xFFFFFFFF));
  final fg = _parseHexColor(custom['text'] ?? '#1a1a1a', const Color(0xFF1A1A1A));
  final border = _parseHexColor(custom['border'] ?? '#d0d7de', const Color(0xFFD0D7DE));
  final canvasSubtle = bg.withValues(alpha: 0.9);
  final accent = _parseHexColor(custom['link'] ?? '#1a5276', const Color(0xFF1A5276));
  final fontSize = (double.tryParse(custom['font_size'] ?? '16') ?? 16.0).clamp(12.0, 36.0);

  final rtl = isArabic || isRtl;

  final fontFamily = rtl
      ? '-apple-system, BlinkMacSystemFont, "Segoe UI", "Tahoma", "Cairo", "Tajawal", "Noto Sans Arabic", "Noto Sans", Helvetica, Arial, sans-serif'
      : '-apple-system, BlinkMacSystemFont, "Segoe UI", "Noto Sans", Helvetica, Arial, sans-serif';

  return {
    "html": Style(
      backgroundColor: bg,
      color: fg,
      fontSize: FontSize(fontSize),
      fontFamily: fontFamily,
      direction: rtl ? TextDirection.rtl : TextDirection.ltr,
      lineHeight: const LineHeight(1.6),
    ),
    "body": Style(
      margin: Margins.all(0),
      padding: HtmlPaddings.all(16),
      direction: rtl ? TextDirection.rtl : TextDirection.ltr,
    ),
    "h1": Style(
      fontSize: FontSize(fontSize * 1.6),
      fontWeight: FontWeight.w600,
      textAlign: rtl ? TextAlign.right : TextAlign.left,
      margin: Margins.only(top: 24, bottom: 16),
      padding: HtmlPaddings.only(bottom: 8),
      border: Border(bottom: BorderSide(color: border, width: 1)),
    ),
    "h2": Style(
      fontSize: FontSize(fontSize * 1.3),
      fontWeight: FontWeight.w600,
      textAlign: rtl ? TextAlign.right : TextAlign.left,
      margin: Margins.only(top: 24, bottom: 16),
      padding: HtmlPaddings.only(bottom: 6),
      border: Border(bottom: BorderSide(color: border, width: 1)),
    ),
    "h3": Style(
      fontSize: FontSize(fontSize * 1.15),
      fontWeight: FontWeight.w600,
      textAlign: rtl ? TextAlign.right : TextAlign.left,
      margin: Margins.only(top: 24, bottom: 16),
    ),
    "h4": Style(
      fontSize: FontSize(fontSize),
      fontWeight: FontWeight.w600,
      textAlign: rtl ? TextAlign.right : TextAlign.left,
      margin: Margins.only(top: 24, bottom: 16),
    ),
    "p": Style(
      margin: Margins.only(bottom: 16),
      textAlign: rtl ? TextAlign.right : TextAlign.left,
      lineHeight: const LineHeight(1.6),
    ),
    "a": Style(
      color: accent,
      textDecoration: TextDecoration.underline,
      fontWeight: FontWeight.bold,
    ),
    "table": Style(
      margin: Margins.only(bottom: 16),
      border: Border.all(color: border, width: 1),
      direction: rtl ? TextDirection.rtl : TextDirection.ltr,
    ),
    "th": Style(
      backgroundColor: canvasSubtle,
      padding: HtmlPaddings.all(10),
      fontWeight: FontWeight.bold,
      textAlign: rtl ? TextAlign.right : TextAlign.left,
      border: Border.all(color: border, width: 1),
    ),
    "td": Style(
      padding: HtmlPaddings.all(10),
      textAlign: rtl ? TextAlign.right : TextAlign.left,
      border: Border.all(color: border, width: 1),
    ),
    "li": Style(
      margin: Margins.only(bottom: 8),
      textAlign: rtl ? TextAlign.right : TextAlign.left,
    ),
    "ul": Style(
      margin: Margins.only(bottom: 16),
      padding: rtl ? HtmlPaddings.only(right: 24, left: 0) : HtmlPaddings.only(left: 24),
    ),
    "ol": Style(
      margin: Margins.only(bottom: 16),
      padding: rtl ? HtmlPaddings.only(right: 24, left: 0) : HtmlPaddings.only(left: 24),
    ),
    "hr": Style(
      height: Height(2, Unit.px),
      backgroundColor: border,
      border: Border.all(style: BorderStyle.none),
      margin: Margins.symmetric(vertical: 24),
    ),
    "pre": Style(
      direction: TextDirection.ltr,
      textAlign: TextAlign.left,
    ),
    "code": Style(
      direction: TextDirection.ltr,
    ),
  };
}

class MarkdownView extends StatelessWidget {
  final String data;
  final bool isSelectable;
  final bool isArabic;
  final bool autoDetectDirection;
  final TextDirection? textDirection;

  const MarkdownView({
    super.key,
    required this.data,
    this.isSelectable = true,
    this.isArabic = false,
    this.autoDetectDirection = true,
    this.textDirection,
  });

  @override
  Widget build(BuildContext context) {
    final isRtlDetected = isArabic || (autoDetectDirection && textDirection == null && AIService.isRtlContent(data));
    final effectiveDirection = textDirection ?? (isRtlDetected ? TextDirection.rtl : TextDirection.ltr);

    if (data.trim().isEmpty) {
      return Text(
        effectiveDirection == TextDirection.rtl ? '*لا يوجد محتوى*' : '*No content*',
        style: const TextStyle(fontStyle: FontStyle.italic, color: AppColors.textSecondary),
        textDirection: effectiveDirection,
      );
    }

    final cleanedData = _sanitizeMarkdown(data);

    // Convert Markdown to HTML
    final htmlData = md.markdownToHtml(
      cleanedData,
      inlineSyntaxes: [InlineMathSyntax()],
      blockSyntaxes: const [BlockMathSyntax()],
      extensionSet: md.ExtensionSet.gitHubFlavored,
    );

    // Re-watch Provider to dynamically rebuild when styling changes
    DeckProvider? provider;
    try {
      provider = context.watch<DeckProvider>();
    } catch (_) {}

    return Directionality(
      textDirection: effectiveDirection,
      child: SelectionArea(
        child: Html(
          data: htmlData,
          style: getHtmlStyleSheet(context, isArabic: isArabic, isRtl: effectiveDirection == TextDirection.rtl),
        onLinkTap: (url, attributes, element) async {
          if (url != null && url.isNotEmpty) {
            final uri = Uri.parse(url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri);
            }
          }
        },
        extensions: [
          // Inline Math Extension
          TagExtension(
            tagsToExtend: {"latex_inline"},
            builder: (extensionContext) {
              final formula = extensionContext.element?.text ?? '';
              try {
                return Math.tex(
                  formula,
                  textStyle: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  onErrorFallback: (err) => Text('\$$formula\$', style: const TextStyle(color: AppColors.error, fontFamily: 'Consolas, monospace')),
                );
              } catch (_) {
                return Text('\$$formula\$', style: const TextStyle(fontFamily: 'Consolas, monospace'));
              }
            },
          ),
          // Block Math Extension
          TagExtension(
            tagsToExtend: {"latex_block"},
            builder: (extensionContext) {
              final formula = extensionContext.element?.text ?? '';
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
            },
          ),
          // Pre (Code Block) Extension
          TagExtension(
            tagsToExtend: {"pre"},
            builder: (extensionContext) {
              final codeElement = extensionContext.element?.getElementsByTagName('code').firstOrNull;
              final code = codeElement?.text ?? extensionContext.element?.text ?? '';
              final classes = codeElement?.classes ?? extensionContext.element?.classes ?? {};
              var language = 'dart';
              for (final c in classes) {
                if (c.startsWith('language-')) {
                  language = c.replaceFirst('language-', '');
                  break;
                }
              }
              return CodeSnippetWidget(code: code.trimRight(), language: language);
            },
          ),
          // Inline Code Extension
          TagExtension(
            tagsToExtend: {"code"},
            builder: (extensionContext) {
              // If it has a pre parent, it is handled by the pre extension
              if (extensionContext.element?.parent?.localName == 'pre') {
                return const SizedBox.shrink();
              }
              final codeText = extensionContext.element?.text ?? '';
              final theme = provider?.noteTheme ?? 'GitHub Light';
              
              Color codeBg = theme.contains('Dark') || theme == 'Solarized Dark'
                  ? const Color(0xFF1E293B)
                  : const Color(0xFFF1F5F9);
              Color codeTextCol = theme.contains('Dark') || theme == 'Solarized Dark'
                  ? const Color(0xFF38BDF8)
                  : const Color(0xFF0284C7);

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: codeBg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  codeText,
                  style: TextStyle(
                    fontFamily: 'Consolas, Courier New, monospace',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: codeTextCol,
                  ),
                ),
              );
            },
          ),
          // Blockquote (Callouts) Extension
          TagExtension(
            tagsToExtend: {"blockquote"},
            builder: (extensionContext) {
              final rawText = extensionContext.element?.text.trim() ?? '';
              
              Color borderColor = AppColors.primary;
              Color bgColor = const Color(0xFFEFF6FF); // blue-50
              IconData icon = Icons.info_outline;
              String alertTitle = 'Note';
              bool isAlert = false;

              if (rawText.startsWith('[!NOTE]') || rawText.startsWith('NOTE:')) {
                borderColor = const Color(0xFF2563EB); // blue
                bgColor = const Color(0xFFEFF6FF);
                icon = Icons.info_outline;
                alertTitle = 'Note';
                isAlert = true;
              } else if (rawText.startsWith('[!TIP]') || rawText.startsWith('TIP:')) {
                borderColor = const Color(0xFF059669); // green
                bgColor = const Color(0xFFECFDF5);
                icon = Icons.lightbulb_outline;
                alertTitle = 'Tip';
                isAlert = true;
              } else if (rawText.startsWith('[!IMPORTANT]') || rawText.startsWith('IMPORTANT:')) {
                borderColor = const Color(0xFF7C3AED); // purple
                bgColor = const Color(0xFFF5F3FF);
                icon = Icons.stars_rounded;
                alertTitle = 'Important';
                isAlert = true;
              } else if (rawText.startsWith('[!WARNING]') || rawText.startsWith('WARNING:')) {
                borderColor = const Color(0xFFD97706); // amber
                bgColor = const Color(0xFFFFFBEB);
                icon = Icons.warning_amber_rounded;
                alertTitle = 'Warning';
                isAlert = true;
              } else if (rawText.startsWith('[!CAUTION]') || rawText.startsWith('CAUTION:')) {
                borderColor = const Color(0xFFDC2626); // red
                bgColor = const Color(0xFFFEF2F2);
                icon = Icons.error_outline;
                alertTitle = 'Caution';
                isAlert = true;
              }

              final theme = provider?.noteTheme ?? 'GitHub Light';

              if (isAlert) {
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
                      Html(
                        data: extensionContext.element?.innerHtml
                            .replaceFirst(RegExp(r'^(\[!NOTE\]|NOTE:|\[!TIP\]|TIP:|\[!IMPORTANT\]|IMPORTANT:|\[!WARNING\]|WARNING:|\[!CAUTION\]|CAUTION:)\s*', caseSensitive: false), '') ?? '',
                        style: getHtmlStyleSheet(extensionContext.buildContext ?? context, isArabic: isArabic),
                      ),
                    ],
                  ),
                );
              }

              Color blockquoteBorderColor = theme.contains('Dark') || theme == 'Solarized Dark'
                  ? const Color(0xFF30363D)
                  : const Color(0xFFD0D7DE);
              Color blockquoteBg = theme.contains('Dark') || theme == 'Solarized Dark'
                  ? const Color(0xFF161B22)
                  : const Color(0xFFF8FAFC);
              Color blockquoteTextColor = theme.contains('Dark') || theme == 'Solarized Dark'
                  ? const Color(0xFF8B949E)
                  : const Color(0xFF475569);

              return Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(vertical: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: blockquoteBg,
                  borderRadius: isArabic
                      ? const BorderRadius.horizontal(left: Radius.circular(8))
                      : const BorderRadius.horizontal(right: Radius.circular(8)),
                  border: isArabic
                      ? Border(right: BorderSide(color: blockquoteBorderColor, width: 4))
                      : Border(left: BorderSide(color: blockquoteBorderColor, width: 4)),
                ),
                child: Html(
                  data: extensionContext.element?.innerHtml ?? '',
                  style: getHtmlStyleSheet(extensionContext.buildContext ?? context, isArabic: isArabic)..addAll({
                    "p": Style(
                      fontSize: FontSize(15),
                      fontStyle: FontStyle.italic,
                      color: blockquoteTextColor,
                      textAlign: isArabic ? TextAlign.right : TextAlign.left,
                      lineHeight: const LineHeight(1.6),
                      margin: Margins.all(0),
                    ),
                  }),
                ),
              );
            },
          ),
          // Custom Image Handler Extension
          TagExtension(
            tagsToExtend: {"img"},
            builder: (extensionContext) {
              final src = extensionContext.attributes['src'] ?? '';
              final alt = extensionContext.attributes['alt'];
              final title = extensionContext.attributes['title'];
              
              if (src.isEmpty) return const SizedBox.shrink();
              
              final uri = Uri.tryParse(src);
              if (uri == null) return const SizedBox.shrink();

              return MarkdownImageWidget(
                uri: uri,
                alt: alt,
                title: title,
              );
            },
          ),
        ],
      ),
    ));
  }
}

/// Pre-processes raw markdown to fix common AI formatting issues before rendering.
String _sanitizeMarkdown(String raw) {
  // 1. Replace <br> tags with newlines
  String out = raw.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');

  // 2. Sanitize image paths: convert local file paths (with Windows drive letters, backslashes, spaces)
  // into valid file:// URIs so markdown parser recognizes them without tripping on spaces.
  out = out.replaceAllMapped(RegExp(r'!\[([^\]]*)\]\(([^)\n]+)\)'), (match) {
    final alt = match.group(1) ?? '';
    var rawDest = match.group(2) ?? '';
    rawDest = rawDest.trim();
    if (rawDest.startsWith('<') && rawDest.endsWith('>')) {
      rawDest = rawDest.substring(1, rawDest.length - 1).trim();
    }

    if (rawDest.startsWith('http://') || rawDest.startsWith('https://') || rawDest.startsWith('data:')) {
      return '![$alt](${rawDest.replaceAll(' ', '%20')})';
    }

    if (rawDest.startsWith('file://')) {
      return '![$alt](${rawDest.replaceAll(' ', '%20')})';
    }

    try {
      final fileUri = Uri.file(rawDest).toString();
      return '![$alt]($fileUri)';
    } catch (_) {
      final safeDest = rawDest.replaceAll(r'\', '/').replaceAll(' ', '%20');
      return '![$alt]($safeDest)';
    }
  });

  // 3. Strip fenced code blocks from inside table rows.
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

/// Rich Markdown Image Viewer with local PC file support, zoom lightbox, and error recovery.
class MarkdownImageWidget extends StatefulWidget {
  final Uri uri;
  final String? title;
  final String? alt;

  const MarkdownImageWidget({
    super.key,
    required this.uri,
    this.title,
    this.alt,
  });

  @override
  State<MarkdownImageWidget> createState() => _MarkdownImageWidgetState();
}

class _MarkdownImageWidgetState extends State<MarkdownImageWidget> {
  bool _isHovered = false;

  bool get _isNetwork => widget.uri.scheme == 'http' || widget.uri.scheme == 'https';
  bool get _isDataUri => widget.uri.scheme == 'data';

  File? _resolveLocalFile() {
    if (_isNetwork || _isDataUri) return null;
    try {
      if (widget.uri.isScheme('file')) {
        try {
          return File.fromUri(widget.uri);
        } catch (_) {
          return File(widget.uri.toFilePath());
        }
      }

      var rawString = Uri.decodeFull(widget.uri.toString());
      rawString = rawString.trim();
      if (rawString.startsWith('<') && rawString.endsWith('>')) {
        rawString = rawString.substring(1, rawString.length - 1).trim();
      }

      if (rawString.startsWith('file://')) {
        try {
          return File.fromUri(Uri.parse(rawString));
        } catch (_) {
          final uriParsed = Uri.tryParse(rawString);
          if (uriParsed != null) {
            return File(uriParsed.toFilePath());
          }
        }
      }

      // Windows drive path like C:/... or c:/...
      if (widget.uri.scheme.length == 1 && RegExp(r'^[a-zA-Z]$').hasMatch(widget.uri.scheme)) {
        final decodedPath = Uri.decodeFull(widget.uri.path);
        final winPath = '${widget.uri.scheme.toUpperCase()}:$decodedPath';
        return File(winPath);
      }

      if (RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(rawString)) {
        return File(rawString);
      }

      if (rawString.isNotEmpty) {
        return File(rawString);
      }

      if (widget.uri.path.isNotEmpty) {
        final decoded = Uri.decodeFull(widget.uri.path);
        return File(decoded);
      }
    } catch (_) {}
    return null;
  }

  String _getDisplayLabel() {
    if (widget.title != null && widget.title!.isNotEmpty) {
      return widget.title!;
    }
    if (widget.alt != null && widget.alt!.isNotEmpty) {
      return widget.alt!;
    }
    final file = _resolveLocalFile();
    if (file != null) {
      return file.uri.pathSegments.isNotEmpty ? file.uri.pathSegments.last : file.path;
    }
    return '';
  }

  void _openImageZoom(BuildContext context, ImageProvider imageProvider, String displayTitle) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 6.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image(image: imageProvider, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!_isNetwork && !_isDataUri)
                    IconButton(
                      icon: const Icon(Icons.folder_open, color: Colors.white, size: 22),
                      tooltip: 'Show in Explorer',
                      style: IconButton.styleFrom(backgroundColor: Colors.black54),
                      onPressed: () {
                        final file = _resolveLocalFile();
                        if (file != null && Platform.isWindows) {
                          Process.run('explorer.exe', ['/select,', file.path]);
                        }
                      },
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 24),
                    tooltip: 'Close',
                    style: IconButton.styleFrom(backgroundColor: Colors.black54),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            ),
            if (displayTitle.isNotEmpty)
              Positioned(
                bottom: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Text(
                    displayTitle,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget(String errorMsg, String? path) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2), // red-50
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCA5A5)), // red-300
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.broken_image_outlined, size: 20, color: Color(0xFFDC2626)),
              SizedBox(width: 8),
              Text(
                'Image Not Found or Inaccessible',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
              ),
            ],
          ),
          if (path != null && path.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFFEE2E2)),
              ),
              child: SelectableText(
                path,
                style: const TextStyle(fontSize: 11, fontFamily: 'Consolas, monospace', color: Color(0xFF475569)),
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            errorMsg,
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF7F1D1D)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayLabel = _getDisplayLabel();

    // 1. Network Image
    if (_isNetwork) {
      final networkProvider = NetworkImage(widget.uri.toString());
      return _buildImageCard(
        context: context,
        imageProvider: networkProvider,
        displayLabel: displayLabel,
        child: Image(
          image: networkProvider,
          fit: BoxFit.contain,
          loadingBuilder: (ctx, child, progress) {
            if (progress == null) return child;
            return Container(
              height: 200,
              alignment: Alignment.center,
              child: const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
            );
          },
          errorBuilder: (ctx, err, stack) => _buildErrorWidget(
            'Failed to load remote image from web URL.',
            widget.uri.toString(),
          ),
        ),
      );
    }

    // 2. Data URI
    if (_isDataUri) {
      try {
        final dataString = widget.uri.data?.contentAsString() ?? widget.uri.toString();
        final commaIndex = dataString.indexOf(',');
        final base64String = commaIndex >= 0 ? dataString.substring(commaIndex + 1) : dataString;
        final bytes = base64Decode(base64String);
        final memoryProvider = MemoryImage(bytes);
        return _buildImageCard(
          context: context,
          imageProvider: memoryProvider,
          displayLabel: displayLabel,
          child: Image(
            image: memoryProvider,
            fit: BoxFit.contain,
            errorBuilder: (ctx, err, stack) => _buildErrorWidget('Invalid embedded base64 image data.', null),
          ),
        );
      } catch (e) {
        return _buildErrorWidget('Failed to parse embedded image data: $e', null);
      }
    }

    // 3. Local PC File Image
    final file = _resolveLocalFile();
    if (file == null || !file.existsSync()) {
      return _buildErrorWidget(
        'Check that the file exists on your PC and the file path is correct.',
        file?.path ?? widget.uri.toString(),
      );
    }

    final fileProvider = FileImage(file);
    return _buildImageCard(
      context: context,
      imageProvider: fileProvider,
      displayLabel: displayLabel,
      localFile: file,
      child: Image(
        image: fileProvider,
        fit: BoxFit.contain,
        errorBuilder: (ctx, err, stack) => _buildErrorWidget(
          'Failed to render image file: $err',
          file.path,
        ),
      ),
    );
  }

  Widget _buildImageCard({
    required BuildContext context,
    required ImageProvider imageProvider,
    required String displayLabel,
    required Widget child,
    File? localFile,
  }) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Image Content with Zoom Overlay
            ClipRRect(
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(13),
                bottom: displayLabel.isNotEmpty ? Radius.zero : const Radius.circular(13),
              ),
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: () => _openImageZoom(context, imageProvider, displayLabel),
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxHeight: 480),
                      alignment: Alignment.center,
                      color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                      child: child,
                    ),
                  ),

                  // Floating Toolbar on Hover / Desktop
                  Positioned(
                    top: 8,
                    right: 8,
                    child: AnimatedOpacity(
                      opacity: _isHovered ? 1.0 : 0.7,
                      duration: const Duration(milliseconds: 150),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.zoom_in, color: Colors.white, size: 18),
                              tooltip: 'Zoom / Fullscreen',
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              padding: EdgeInsets.zero,
                              onPressed: () => _openImageZoom(context, imageProvider, displayLabel),
                            ),
                            if (localFile != null && Platform.isWindows) ...[
                              const SizedBox(width: 2),
                              IconButton(
                                icon: const Icon(Icons.folder_open, color: Colors.white, size: 18),
                                tooltip: 'Open File in Explorer',
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                padding: EdgeInsets.zero,
                                onPressed: () {
                                  Process.run('explorer.exe', ['/select,', localFile.path]);
                                },
                              ),
                            ],
                            const SizedBox(width: 2),
                            IconButton(
                              icon: const Icon(Icons.copy, color: Colors.white, size: 16),
                              tooltip: 'Copy Path',
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                final pathText = localFile?.path ?? widget.uri.toString();
                                Clipboard.setData(ClipboardData(text: pathText));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('📋 Image path copied to clipboard'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Caption Bar if title or alt is available
            if (displayLabel.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9), // slate-100
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(13)),
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.photo_outlined, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        displayLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF475569),
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

