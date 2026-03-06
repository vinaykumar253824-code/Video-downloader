import 'dart:io';
import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:file_picker/file_picker.dart';

void main() => runApp(MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: ThemeData(primarySwatch: Colors.red),
  home: WindowsDownloader(),
));

class WindowsDownloader extends StatefulWidget {
  // Key error fix karne ke liye constructor update kiya
  WindowsDownloader({super.key});

  @override
  _WindowsDownloaderState createState() => _WindowsDownloaderState();
}

class _WindowsDownloaderState extends State<WindowsDownloader> {
  final TextEditingController _urlController = TextEditingController();
  bool _isDownloading = false;
  double _progress = 0;

  // Type MuxedStreamInfo rakhein kyunki humein quality labels chahiye
  List<MuxedStreamInfo> _availableQualities = [];
  MuxedStreamInfo? _selectedQuality;
  String _videoTitle = "";

  // 1. Video ki Qualities Fetch karna
// main.dart mein fetchVideoInfo function ko isse replace karein
  Future<void> fetchVideoInfo(String url) async {
    if (url.isEmpty) return;

    var yt = YoutubeExplode();
    try {
      var video = await yt.videos.get(url);
      var manifest = await yt.videos.streamsClient.getManifest(url);

      // FIX: Saari qualities fetch karne ke liye hum muxed streams ko filter karenge
      // Taki audio + video dono saath milein 720p tak
      var allMuxedStreams = manifest.muxed.where((s) => s.container.name == 'mp4').toList();

      setState(() {
        _videoTitle = video.title;
        _availableQualities = allMuxedStreams;
        if (_availableQualities.isNotEmpty) {
          // Sabse high quality (pehle 720p) select karne ke liye:
          _availableQualities.sort((a, b) => b.size.totalBytes.compareTo(a.size.totalBytes));
          _selectedQuality = _availableQualities.first;
        }
      });
    } catch (e) {
      // Agar "Bot" wala error aaye toh user ko clear message dikhayein
      if (e.toString().contains("Sign in")) {
        _showError("YouTube ne temporary block kiya hai. Kuch der baad try karein ya doosra link use karein.");
      } else {
        _showError("Error: $e");
      }
    } finally {
      yt.close();
    }
  }

  // 2. Download Function
  Future<void> downloadVideo() async {
    if (_selectedQuality == null) return;

    String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Video kahan save karni hai?',
    );

    if (selectedDirectory == null) return;

    setState(() {
      _isDownloading = true;
      _progress = 0;
    });

    var yt = YoutubeExplode();
    try {
      String cleanTitle = _videoTitle.replaceAll(RegExp(r'[^\w\s]+'), '');
      String fullPath = "$selectedDirectory\\$cleanTitle.mp4";

      var stream = yt.videos.streamsClient.get(_selectedQuality!);
      var file = File(fullPath);
      var fileStream = file.openWrite();

      var totalSize = _selectedQuality!.size.totalBytes;
      var downloaded = 0;

      await for (var data in stream) {
        downloaded += data.length;
        setState(() {
          _progress = downloaded / totalSize;
        });
        fileStream.add(data);
      }

      await fileStream.flush();
      await fileStream.close();

      _showSuccess("Success! Video saved: $fullPath");
    } catch (e) {
      _showError("Download fail: $e");
    } finally {
      yt.close();
      setState(() { _isDownloading = false; });
    }
  }

  void _showError(String msg) {
    showDialog(context: context, builder: (_) => AlertDialog(title: Text("Error"), content: Text(msg)));
  }

  void _showSuccess(String msg) {
    showDialog(context: context, builder: (_) => AlertDialog(title: Text("Success"), content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Advanced YouTube Downloader")),
      body: Padding(
        padding: EdgeInsets.all(30),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _urlController,
                decoration: InputDecoration(
                  labelText: "YouTube Link Paste Karein",
                  border: OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.search),
                    onPressed: () => fetchVideoInfo(_urlController.text),
                  ),
                ),
              ),
              if (_videoTitle.isNotEmpty) ...[
                SizedBox(height: 30),
                Card(
                  elevation: 5,
                  child: Padding(
                    padding: EdgeInsets.all(15),
                    child: Column(
                      children: [
                        Text(_videoTitle, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        SizedBox(height: 15),

                        // FIX for Line 151: List type matching
                        DropdownButton<MuxedStreamInfo>(
                          isExpanded: true,
                          value: _selectedQuality,
                          items: _availableQualities.map((stream) {
                            return DropdownMenuItem<MuxedStreamInfo>(
                              value: stream,
                              child: Text("${stream.videoQualityLabel} (${(stream.size.totalMegaBytes).toStringAsFixed(1)} MB)"),
                            );
                          }).toList(),
                          onChanged: (val) => setState(() => _selectedQuality = val),
                        ),

                        SizedBox(height: 20),
                        _isDownloading
                            ? Column(
                          children: [
                            LinearProgressIndicator(value: _progress, minHeight: 10),
                            SizedBox(height: 10),
                            Text("${(_progress * 100).toStringAsFixed(0)}% Downloaded"),
                          ],
                        )
                            : ElevatedButton.icon(
                          icon: Icon(Icons.download),
                          label: Text("Download Now"),
                          style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50)),
                          onPressed: downloadVideo,
                        ),
                      ],
                    ),
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}