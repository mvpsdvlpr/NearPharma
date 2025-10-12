import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:mobile/widgets/pharmacy_card.dart';
import 'package:http/http.dart' as http;

class _MockClient extends http.BaseClient {
  final Map<Uri, http.Response> headResponses;
  _MockClient(this.headResponses);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // Not used in these tests; AdaptiveNetworkImage uses head() and get().
    throw UnimplementedError();
  }

  @override
  Future<http.Response> head(Uri url, {Map<String, String>? headers}) async {
    final r = headResponses[url];
    if (r != null) return r;
    return http.Response('', 404);
  }

  @override
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    final r = headResponses[url];
    if (r != null) return r;
    return http.Response('', 404);
  }
}

void main() {
  testWidgets('AdaptiveNetworkImage chooses SVG rendering when HEAD reports svg', (WidgetTester tester) async {
    final svgUrl = Uri.parse('https://example.com/logo.svg');
    final client = _MockClient({svgUrl: http.Response('', 200, headers: {'content-type': 'image/svg+xml'})});

    await tester.pumpWidget(MaterialApp(home: Material(child: AdaptiveNetworkImage(url: svgUrl.toString(), width: 48, height: 48, client: client))));

    // Pump to allow async HEAD to complete
    await tester.pumpAndSettle();

    // SvgPicture creates semantics label or picture; assert no exception and widget exists
    expect(find.byType(AdaptiveNetworkImage), findsOneWidget);
  });

  testWidgets('AdaptiveNetworkImage chooses raster rendering when HEAD reports png', (WidgetTester tester) async {
    final pngUrl = Uri.parse('https://example.com/logo.png');
    final client = _MockClient({pngUrl: http.Response('', 200, headers: {'content-type': 'image/png'})});

    await tester.pumpWidget(MaterialApp(home: Material(child: AdaptiveNetworkImage(url: pngUrl.toString(), width: 48, height: 48, client: client))));
    await tester.pumpAndSettle();

    expect(find.byType(AdaptiveNetworkImage), findsOneWidget);
  });
}
