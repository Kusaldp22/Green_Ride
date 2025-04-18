import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PayPalWebView extends StatefulWidget {
  final String approvalUrl;
  final String paymentId;

  const PayPalWebView({
    Key? key,
    required this.approvalUrl,
    required this.paymentId,
  }) : super(key: key);

  @override
  _PayPalWebViewState createState() => _PayPalWebViewState();
}

class _PayPalWebViewState extends State<PayPalWebView> {
  bool isLoading = true;
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();

    // Initialize the WebViewController
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (error) {
            print('WebView Error: ${error.description}');
            setState(() => isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text('Failed to load page: ${error.description}')),
            );
          },
          onPageFinished: (String url) {
            setState(() {
              isLoading = false;
            });
          },
          onNavigationRequest: (NavigationRequest request) {
            // Check if the URL is the success or cancel URL
            if (request.url.contains('example.com/success')) {
              Navigator.pop(context, 'success');
              return NavigationDecision.prevent;
            } else if (request.url.contains('example.com/cancel')) {
              Navigator.pop(context, 'cancelled');
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.approvalUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PayPal Payment'),
        backgroundColor: Colors.green,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context, 'cancelled'),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (isLoading)
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
              ),
            ),
        ],
      ),
    );
  }
}
