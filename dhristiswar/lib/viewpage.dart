import 'dart:convert';
import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:text_neon_widget/text_neon_widget.dart';
import 'dart:math';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path/path.dart' as Path;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:lottie/lottie.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:camera/camera.dart';


class MainPage extends StatefulWidget {
  MainPage({super.key,required this.startupsound});
  bool startupsound=true;
  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  bool isloading=false;
  bool noStartUpAudio=false;
  String _lastWords = '';
  String mic_words='';
  double _currentVolume = 0.0;
  double _initialVolume = 0.0;
  bool cameraViewEnabled=false;
  late AudioPlayer player = AudioPlayer();
  final FlutterTts flutterTts = FlutterTts();
  bool isSpeaking = false;
  List<String> startToken=["Your image describes ","This image shows ","I can see an image of  ","I can visualize that "];
  String endToken=" . Thank You !!"; 
  GlobalKey globalKey=GlobalKey();
  List<CameraDescription> cameras=[];
  XFile? cameraPicture;
  CameraController? controller;
  bool toggleswitch=false;
 

  @override
  void initState() {
    super.initState();
    initializeCamera();
    _initSpeech();
    flutterTts.clearVoice();
    player = AudioPlayer();
    player.stop();
    noStartUpAudio= widget.startupsound;
    if(noStartUpAudio==false){
      player.stop();
      player.dispose();
    }
    if(noStartUpAudio==true){
    flutterTts.clearVoice();
    
    
    // Set the release mode to keep the source after playback has completed.
    player.setReleaseMode(ReleaseMode.stop);
   
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await player.setSource(AssetSource('start_sound.mp3'));
      player.resume();
    });
    }
    FlutterVolumeController.addListener((volume) {
      if(_initialVolume<_currentVolume || _initialVolume<_currentVolume)
      { 
        flutterTts.clearVoice();
        if(!cameraViewEnabled){
         initializeCamera();
        cameraViewEnabled=true;
        flutterTts.clearVoice();
        if(controller!.value.isInitialized)
        flutterTts.speak('Opened Camera. Tap to capture.');
      }}
      setState(() {
        _currentVolume = volume;
      });
    });
    _initialVolume = _currentVolume;
    flutterTts.setLanguage("en-GB");
    flutterTts.setVolume(0.8);
    flutterTts.setSpeechRate(0.3);
    flutterTts.setPitch(1.0);
    flutterTts.setStartHandler(() {
    setState(() {
      isSpeaking = true;
    });
  });
  flutterTts.setCompletionHandler(() {
    setState(() {
      isSpeaking = false;
    });
  });
  }

  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    setState(() {});
  }

  void initializeCamera() async {
  // Fetch available cameras
  cameras = await availableCameras();
  // Set up the first camera for preview
  controller = CameraController(cameras.first, ResolutionPreset.medium,enableAudio: false,);
  // Initialize the camera controller
  await controller?.initialize().then((_) {
      if (!mounted) {
        return;
      }});
  // Update the state to re-render the widget with the camera preview
  setState(() {});
}


  
  Future<void> getCaption(context, ImageSource? source,XFile? img, String? txt) async{
    if(source!=null){
     img = await ImagePicker().pickImage(source: source);
     cameraPicture=img;
     }
    if(img!=null){
    print('Image Picked');
      try {
    // Prepare the image file
    var imageFile = await MultipartFile.fromFile(img.path, filename: img.name);

    // Create FormData with a single file entry for blip-vq and blip-base model
    var data;
    if(txt==null){
    data = FormData.fromMap({
      'file': imageFile,
    });
    setState((){
      isloading=true;
        });
    }
     if(txt!=null){
    // Map<dynamic,MultipartFile> files={};
    // files['file']=await MultipartFile.fromFile(img.path, filename: img.name);
    List<String> datas = txt.split(" ");
    
    
    data=FormData.fromMap({
      'ques': datas,
      'file': await MultipartFile.fromFile(img.path, filename: img.name)
    });
    
    }
    // Create a Dio instance
    var dio = Dio();
    
    // Send the POST request with error handling
    var response;
    if(txt==null){
      response = await dio.post(
      'http://localhost:9090/upload_file', 
      
      data: data,
      options: Options(method: 'POST'),
    );
    }
     if(txt!=null){
      response = await dio.post(
      'http://localhost:9090/upload_file', 
      
      data: data,
      options: Options(method: 'POST'),
    );
      setState(() {
        isloading=false;
        // _lastWords=response.data;
      });
      
      //flutterTts.speak("Your question is: "+_lastWords);
     // ResultPage(lastWord: _lastWords,cameraPicture: cameraPicture);
    }
      
    if (response.statusCode == 200) {
      var decodedJson=(json.encode(response.data));
      _lastWords=decodedJson.replaceAll(RegExp(r'{'), '').replaceAll(RegExp(r'}'), '').replaceAll(RegExp(r':'), ' ').replaceAll(RegExp(r']'), '').replaceAll(RegExp(r'"'), '').replaceAll(RegExp(r'caption'), '');
      flutterTts.clearVoice();
      setState(() {
        isloading=false;
      });
        
      if(txt==null){
       _lastWords=startToken[Random().nextInt(3)]+_lastWords+endToken;
       }
      if(txt!=null)
       _lastWords=" "+_lastWords;
      //  Navigator.push(context, MaterialPageRoute(builder: (context) => ResultPage(lastWord: _lastWords,cameraPicture: cameraPicture,)));
      //  }

       await flutterTts.speak(_lastWords +".. Double Tap to ask questions.");
       
    } else {
      flutterTts.speak("No answer");
      print(response.statusMessage);
    }
  } on DioError catch (e) {
    // Handle specific DioError types (optional)
    if (DioErrorType.connectionTimeout == e.type) {
      print('Connection timed out.');
    } else if (DioErrorType.badResponse == e.type) {
      // Handle server-side errors (e.g., status code not 200)
      print('Server error: ${e.response!.statusCode}');
    } else {
      // Handle other DioError types
      print('Error uploading image: ${e.message}');
    }
    rethrow; // Re-throw for potential caller handling (optional)
  } catch (e) {
    // Catch other general exceptions (optional)
    print('Unexpected error: $e');
  }
      // } 
  }
  }

  void takePicture() async {
  try {
    // Construct the path where the image will be saved
    final path = Path.join(
      (await getApplicationDocumentsDirectory()).path,
      '${DateTime.now()}.png',
    );
    // Capture the image and save it to the path
    await controller!.takePicture().then((value)  {
      flutterTts.clearVoice();
      flutterTts.speak("Picture Clicked.. Please Wait");
      getCaption(context, null, value,null);
      setState(() {
    cameraPicture=value;
    cameraViewEnabled=false;  
    });
    });
    // Show a message indicating the image was saved successfully
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Picture saved to: $path'),
      ),
    );
  } catch (e) {
    // Handle errors
    print('Error taking picture: $e');
  }
}
  void _startListening() async {
    
    await _speechToText.listen(onResult: _onSpeechResult);

    setState(() {
    });
  }

  void _stopListening() async {
    await _speechToText.stop();
    setState(() {});
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() {
      mic_words = result.recognizedWords;
    });

  }

  @override
  void dispose(){
    setState(() {
      noStartUpAudio=widget.startupsound;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // leading: IconButton(
        //     icon: Image.asset('assets/dhristiswarlogo.png'), // Replace 'assets/icon.png' with your image asset path
        //     onPressed: () {
        //       getDrawer();
        //     },
        //   ),
        title: Text('Welcome!',style: TextStyle(color: Colors.white),),
          backgroundColor: Color.fromARGB(255, 37, 91, 153),
          ),
        drawer: getDrawer(),
        backgroundColor: Colors.amberAccent,
      body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/bg.png',
              fit: BoxFit.cover,
            ),
            Center(
              child:
            cameraViewEnabled?cameraPreview():Container(
        child:SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            PTTextNeon(text: 'I m a g e  S p e a k s',color: Colors.lightBlue,
            font: "five",shine: true,fontSize: 35,
            strokeWidthTextHigh: 3,blurRadius: 25,
            strokeWidthTextLow: 1,backgroundColor: Colors.black,),
          mic_words!=''?Lottie.asset('assets/mic_animation.json'):Text(''),
          cameraPicture!=null?Container(
                padding: EdgeInsets.all(16),
                child: isloading?Lottie.asset('assets/loading_animation.json'):GestureDetector(
                  onDoubleTap: () async{
                 flutterTts.clearVoice();
                cameraViewEnabled=false;
              if(cameraPicture!=null && !cameraViewEnabled && _speechToText.isNotListening){
              flutterTts.speak('Ask your query?');
              _startListening();
              }
              if(_speechToText.isNotListening && mic_words!=''){
                await flutterTts.speak("Your question is: "+mic_words);
                await getCaption(context, null, cameraPicture, mic_words);
                mic_words='';
              }
              if(_speechToText.isListening){
                _stopListening();
               // await flutterTts.speak("Your question is: "+mic_words);
                await getCaption(context, null, cameraPicture, mic_words);
              }
                  },            
           child: Column(
              children:[
                Container(
            // Adjust width and height as desired
            width: 300.0,
            height: 300.0,
            decoration: BoxDecoration(
              // Background color for the container
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(20.0), // Rounded corners
              boxShadow: [
                // Add inner shadow for depth
                BoxShadow(
                  color: Color.fromARGB(255, 90, 90, 90)!.withOpacity(0.2), // Shadow color
                  offset: Offset(5.0, 5.0), // Shadow offset
                  blurRadius: 10.0, // Shadow blur radius
                ),
                // Add outer glow for style
                BoxShadow(
                  color: Color.fromARGB(255, 231, 176, 93).withOpacity(0.5), // Glow color
                  offset: Offset(-5.0, -5.0), // Glow offset (opposite direction)
                  blurRadius: 15.0, // Glow blur radius
                  spreadRadius: -2.0, // Negative spread for inner glow effect
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20.0), // Clip image to match container shape
              child: Image(image: FileImage(File(cameraPicture!.path)),
                 // Replace with your image URL
                fit: BoxFit.fill, // Fill the container
              ),
            ),
          ),
          SizedBox(height: 30,),
          Container(
            padding: EdgeInsets.all(10.0),
            height: 100,
            width: 300,
            decoration: BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.circular(20.0)),
            child:SingleChildScrollView(
              child:Text('$_lastWords',
              style: TextStyle(
                fontSize: 16.0, // Adjust font size as desired
                color: Colors.black // Color of the underline
              ),
        )))],)))  :
          GestureDetector(onTap:()=>{
            player.stop(),flutterTts.speak("Press Volume button to capture."),
          } ,child: Lottie.asset('assets/walking_animation.json')),
          SizedBox(height: 10,),
  //           ElevatedButton(onPressed: (){
  //               cameraViewEnabled=false;
  //          getCaption(context,ImageSource.camera,null,null);
  //           }, style: ElevatedButton.styleFrom(
  //   shape: RoundedRectangleBorder(
  //     borderRadius: BorderRadius.circular(50.0), // Adjust for desired roundness
  //   ),
  //   padding: EdgeInsets.all(20.0), // Adjust padding for button size
  //   minimumSize: Size(80.0, 80.0), // Set minimum size for the button
  //  // primary: Colors.red, // Change color as desired
  // ),
  // child: Icon(Icons.camera_alt, size: cameraPicture!=null?50.0:30))
 
          ],
        )),
      ),)]),
      floatingActionButton: FloatingActionButton(
        onPressed: (){
           getCaption(context,ImageSource.gallery,null,null);},
        tooltip: 'Listen',
        child: Icon(Icons.photo_library),
      ),
    );
  }

  Widget cameraPreview(){
    final size = MediaQuery.of(context).size;
  final deviceRatio = (size.width+50) / size.height;
    return GestureDetector(
    onTap:() async{
      takePicture();},
    child: Scaffold(
   body: (controller == null || !controller!.value.isInitialized)?Container()
                                  :AspectRatio(aspectRatio: deviceRatio,child: CameraPreview(key:globalKey,controller!)),
  ),
  );
  }


  Widget getDrawer()=>Drawer(
    backgroundColor: Colors.white,
        child: ListView(
          padding: EdgeInsets.all(10),
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
                image: DecorationImage(
      image: AssetImage('assets/Picture1.png'),
      fit: BoxFit.scaleDown, // Adjusts the image to cover the entire container
    ),
    // Add shape
    shape: BoxShape.rectangle, // Use BoxShape.rectangle for a rectangular shape
    // Add border
    border: Border.all(
      color: Colors.black,
      width: 2.0,
    ),
    // Add border radius (only for rectangular shapes)
    borderRadius: BorderRadius.circular(10.0),
    // Add shadow
    boxShadow: [
      BoxShadow(
        color: Colors.grey.withOpacity(0.5),
        spreadRadius: 5,
        blurRadius: 7,
        offset: Offset(0, 3), // changes position of shadow
      ),
    ],
    // Add gradient
    gradient: LinearGradient(
      colors: [Colors.red, Colors.blue],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  
              ),
              child: Text(
                '',
                style: TextStyle(
                  color: Color.fromARGB(255, 10, 222, 233),
                  fontSize: 24,
                  fontStyle: FontStyle.italic
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.home),
              title: Text('Home'),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => MainPage(startupsound: true,)),
                );}
            ),
            ListTile(
              leading: Icon(Icons.remove_done),
              title: Text('Volume Controls'),
              onTap: () {}
            ),
            Switch(value: toggleswitch,
              onChanged: (value) {
                if(value==false){
                  Navigator.push(context, MaterialPageRoute(builder: (context) => MainPage(startupsound: true,)));
                }
                else{
                    FlutterVolumeController.removeListener();
                    flutterTts.clearVoice();
                    flutterTts.speak("Volume Control removed");
                    value=false;
                    toggleswitch=true;
                }
                setState(() {
                  toggleswitch = !value; 
                });}),
                ListTile(
              leading: Icon(Icons.volume_mute),
              title: Text('Initialize'),
              onTap: () {}
            ),
              Switch(value: widget.startupsound!,
              onChanged: (value) {
                if(value==false){
                  Navigator.push(context, MaterialPageRoute(builder: (context) => MainPage(startupsound:false)));
                }
                else{
                    FlutterVolumeController.removeListener();
                    flutterTts.clearVoice();
                    flutterTts.speak("Start up sound removed");
                    value=false;
                   // widget.startupsound=true;
                }
                setState(() {
                  
                });}),
                

            Divider(),
            ListTile(
              title: Text('About'),
              onTap: ()=>{
              },
            ),
            
          ],
        ),
      );
  
}