import 'dart:io';
import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';

void main() => runApp(MaterialApp(home: WindowsDownloader()));

class WindowsDownloader extends StatefulWidget {
  @override
  _WindowsDownloaderState createState() => _WindowsDownloaderState();
}

class _WindowsDownloaderState extends State<WindowsDownloader> {
  final TextEditingController _urlController = TextEditingController();
  bool _isDownloading = false;
  double _progress = 0;
  List<MuxedStreamInfo> _availableQualities = [];
  MuxedStreamInfo? _selectedQuality;
  String _videoTitle = "";

  // 1. Video ki Qualities Fetch Karna
  Future<void> fetchVideoInfo(String url) async {
    var yt = YoutubeExplode();
    try {
      var video = await yt.videos.get(url);
      var manifest = await yt.videos.streamsClient.getManifest(url);

      setState(() {
        _videoTitle = video.title;
        // 720p tak ki saari muxed streams nikalna
        _availableQualities = manifest.muxed.toList();
        _selectedQuality = _availableQualities.first;
      });
    } catch (e) {
      print("Error fetching info: $e");
    } finally {
      yt.close();
    }
  }

  // 2. Download Function
  Future<void> downloadVideo() async {
    if (_selectedQuality == null) return;

    // 1. Pehle Folder select karwayein (Windows ke liye ye best hai)
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Folder to Save Video',
    );

    if (selectedDirectory == null) return; // Agar user ne cancel kar diya

    setState(() {
      _isDownloading = true;
      _progress = 0;
    });

    var yt = YoutubeExplode();
    try {
      // 2. File ka poora naam aur rasta banayein
      String cleanTitle = _videoTitle.replaceAll(RegExp(r'[^\w\s]+'), '');
      String fullPath = "$selectedDirectory\\$cleanTitle.mp4"; // Windows uses backslash \

      var stream = yt.videos.streamsClient.get(_selectedQuality!);
      var file = File(fullPath);
      var fileStream = file.openWrite();

      num totalSize = _selectedQuality!.size.totalBytes;
      num downloaded = 0;

      // 3. Data likhna shuru karein
      await for (var data in stream) {
        downloaded += data.length;
        setState(() {
          _progress = downloaded / totalSize;
        });
        fileStream.add(data);
      }

      await fileStream.flush();
      await fileStream.close();

      showDialog(
          context: context,
          builder: (_) => AlertDialog(content: Text("Success! Video saved at: $fullPath"))
      );
    } catch (e) {
      print("Download Error: $e");
    } finally {
      yt.close();
      setState(() { _isDownloading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Windows YouTube Downloader")),
      body: Padding(
        padding: EdgeInsets.all(30),
        child: Column(
          children: [
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                hintText: "Paste Link Here",
                suffixIcon: IconButton(
                  icon: Icon(Icons.search),
                  onPressed: () => fetchVideoInfo(_urlController.text),
                ),
              ),
            ),
            if (_videoTitle.isNotEmpty) ...[
              SizedBox(height: 20),
              Text("Video: $_videoTitle", style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownButton<MuxedStreamInfo>(
                value: _selectedQuality,
                items: _availableQualities.map((q) {
                  return DropdownMenuItem(
                    value: q,
                    child: Text("${q.videoQualityLabel} (${(q.size.totalMegaBytes).toStringAsFixed(1)} MB)"),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedQuality = val),
              ),
              SizedBox(height: 20),
              _isDownloading
                  ? LinearProgressIndicator(value: _progress)
                  : ElevatedButton(onPressed: downloadVideo, child: Text("Download Now")),
            ]
          ],
        ),
      ),
    );
  }
}