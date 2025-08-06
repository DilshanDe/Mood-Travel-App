import 'package:flutter/material.dart';
import '../services/model_update_service.dart';

class ModelUpdateIndicator extends StatefulWidget {
  final Widget child;

  const ModelUpdateIndicator({Key? key, required this.child}) : super(key: key);

  @override
  _ModelUpdateIndicatorState createState() => _ModelUpdateIndicatorState();
}

class _ModelUpdateIndicatorState extends State<ModelUpdateIndicator> {
  bool _isUpdating = false;
  double _progress = 0.0;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
    if (await ModelUpdateService.needsModelUpdate()) {
      _showUpdateDialog();
    }
  }

  void _showUpdateDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.psychology, color: Colors.purple),
            SizedBox(width: 10),
            Text('AI Model Update'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('A new AI model is available with improved recommendations!'),
            SizedBox(height: 20),
            if (_isUpdating) ...[
              LinearProgressIndicator(value: _progress),
              SizedBox(height: 10),
              Text(_status, style: TextStyle(fontSize: 12)),
            ],
          ],
        ),
        actions: [
          if (!_isUpdating) ...[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Later'),
            ),
            ElevatedButton(
              onPressed: _updateModel,
              child: Text('Update Now'),
            ),
          ] else ...[
            TextButton(
              onPressed: null,
              child: Text('Updating...'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _updateModel() async {
    setState(() {
      _isUpdating = true;
      _progress = 0.0;
      _status = 'Starting update...';
    });

    final success = await ModelUpdateService.downloadAndUpdateModel(
      onProgress: (progress) {
        setState(() {
          _progress = progress;
        });
      },
      onStatusUpdate: (status) {
        setState(() {
          _status = status;
        });
      },
    );

    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(' AI model updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
