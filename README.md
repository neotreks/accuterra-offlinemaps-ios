# accuterra-offlinemaps-ios
Example app demonstrating how to create AccuTerra Maps offline cache using Mapbox SDK for iOS

To run this app, you need Cocoapods and Mapbox Token, which you can obtain on https://account.mapbox.com after registation. To load the AccuTerra Maps style you need API key, which you can get on https://account.accuterra.com. 

1. Clone the repo
2. In a terminal, "cd" to the directory containing the sample of interest. This will contain the project file, workspace, and Podfile
3. Type the following Cocoapods command:
```
pod install
```
4. Open the workspace file (not the project file)
5. Set Mapbox token in info.plist file to key MGLMapboxAccessToken 
6. Set AccuTerra API key in info.plist file to key ACCUTERRA_MAP_API_KEY
7. Launch the target application and you should see the demostrated functionality.
