//
//  OfflinePackExample.swift
//  AccuTerraOfflineMaps
//
//  Created by Rudolf Kopřiva on 23/09/2020.
//
// Example of creating offline cache for AccuTerra maps using Mapbox SDK

import UIKit
import Mapbox

class OfflinePackExample: UIViewController, MGLMapViewDelegate {
    @IBOutlet weak var mapView: MGLMapView!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var cacheButton: UIButton!
    
    private var offlinePacksCounter: Int = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let accuTerraStyleURL = Bundle.main.infoDictionary?["ACCUTERRA_MAP_STYLE_URL"] as? String, !accuTerraStyleURL.isEmpty else {
            fatalError("ACCUTERRA_MAP_STYLE_URL not set in Info.plist")
        }
        
        guard let accuTerraMapAPIKey = Bundle.main.infoDictionary?["ACCUTERRA_MAP_API_KEY"] as? String, !accuTerraMapAPIKey.isEmpty else {
            fatalError("ACCUTERRA_MAP_API_KEY not set in Info.plist")
        }
        
        let styleURL = accuTerraStyleURL + "?key=" + accuTerraMapAPIKey

        // Set AccuTerra style to Mapbox
        mapView.styleURL = URL(string: styleURL)
        
        // Set default location for this demo (Castle Rock CO)
        mapView.setCenter(CLLocationCoordinate2D(latitude: 39.38, longitude: -104.86),
                          zoomLevel: 13, animated: false)

        // Setup offline pack notification handlers.
        NotificationCenter.default.addObserver(self, selector: #selector(offlinePackProgressDidChange), name: NSNotification.Name.MGLOfflinePackProgressChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(offlinePackDidReceiveError), name: NSNotification.Name.MGLOfflinePackError, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(offlinePackDidReceiveMaximumAllowedMapboxTiles), name: NSNotification.Name.MGLOfflinePackMaximumMapboxTilesReached, object: nil)
        self.cacheButton.isHidden = true
    }

    func mapViewDidFinishLoadingMap(_ mapView: MGLMapView) {
        print("Map loaded")
        self.cacheButton.isHidden = false
        offlinePacksCounter = MGLOfflineStorage.shared.packs?.count ?? 0
        printListOfOfflinePacks()
    }
    
    func mapViewDidFailLoadingMap(_ mapView: MGLMapView, withError error: Error) {
        print("Map failed to load \(error)")
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }

    deinit {
        // Remove offline pack observers.
        print("Removing offline pack notification observers")
        NotificationCenter.default.removeObserver(self)
    }
    
    @IBAction func cacheButtonPressed() {
        if cacheButton.isSelected {
            MGLOfflineStorage.shared.packs?.forEach({ (pack) in
                if pack.state == .active {
                    pack.suspend()
                    
                    if let offlinePackDetails = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(pack.context) as? [String: Any] {
                        let packName = offlinePackDetails["name"] ?? "unknown"
                        MGLOfflineStorage.shared.removePack(pack) { (error) in
                            if let error = error {
                                debugPrint("Could not remove pack “\(packName)“ \(error)")
                            } else {
                                debugPrint("Offline pack “\(packName)“ removed")
                            }
                        }
                    }
                }
            })
        } else {
            startOfflinePackDownload()
        }
        cacheButton.isSelected = !cacheButton.isSelected
        self.progressView.isHidden = !cacheButton.isSelected
    }

    /**
     * This method will cache current map style,
     * current visible region and zoom levels from current to max or if current is more than 13 the max is current + 2
     */
    func startOfflinePackDownload() {
        self.progressView.progress = 0
        
        // Because we are not caching Mapbox tiles, we can increase offline cache limit
        
        MGLOfflineStorage.shared.setMaximumAllowedMapboxTiles(UInt64.max)
        
        // Create a region that includes the current viewport and any tiles needed to view it when zoomed further in.
        // Because tile count grows exponentially with the maximum zoom level, you should be conservative with your `toZoomLevel` setting.
        let region = MGLTilePyramidOfflineRegion(styleURL: mapView.styleURL, bounds: mapView.visibleCoordinateBounds, fromZoomLevel: mapView.zoomLevel, toZoomLevel: max(14, mapView.zoomLevel + 2))

        // Store some data for identification purposes alongside the downloaded resources.
        offlinePacksCounter += 1
        let offlinePackDetails: [String: Any] = [
            "name": "Offline Pack \(offlinePacksCounter)",
            "minx": region.bounds.sw.longitude,
            "miny": region.bounds.sw.latitude,
            "maxx": region.bounds.ne.longitude,
            "maxy": region.bounds.ne.latitude
        ]
        let context = try! NSKeyedArchiver.archivedData(withRootObject: offlinePackDetails, requiringSecureCoding: false)

        // Create and register an offline pack with the shared offline storage object.
        MGLOfflineStorage.shared.addPack(for: region, withContext: context) { (pack, error) in
            guard error == nil else {
                // The pack couldn’t be created for some reason.
                print("Error: \(error?.localizedDescription ?? "unknown error")")
                return
            }

            // Start downloading.
            pack!.resume()
        }

    }

    // MARK: - MGLOfflinePack notification handlers
    
    /**
     * Called when Mapbox region status or progress changes
     */
    @objc func offlinePackProgressDidChange(notification: NSNotification) {
        // Get the offline pack this notification is regarding,
        // and the associated details of the pack
        
        
        
        if let pack = notification.object as? MGLOfflinePack,
           let offlinePackDetails = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(pack.context) as? [String: Any] {
            let packName = offlinePackDetails["name"] ?? "unknown"
            
            let progress = pack.progress
            // or notification.userInfo![MGLOfflinePackProgressUserInfoKey]!.MGLOfflinePackProgressValue
            let completedResources = progress.countOfResourcesCompleted
            let expectedResources = progress.countOfResourcesExpected

            // Calculate current progress percentage.
            let progressPercentage = Float(completedResources) / Float(expectedResources)

            progressView.progress = progressPercentage
            // If this pack has finished, print its size and resource count.
            if completedResources == expectedResources {
                let byteCount = ByteCountFormatter.string(fromByteCount: Int64(pack.progress.countOfBytesCompleted), countStyle: ByteCountFormatter.CountStyle.memory)
                print("Offline pack “\(packName)” completed: \(byteCount), \(completedResources) resources")
                self.cacheButton.isSelected = false
                self.progressView.isHidden = true
            } else {
                // Otherwise, print download/verification progress.
                print("Offline pack “\(packName)” has \(completedResources) of \(expectedResources) resources — \(String(format: "%.2f", progressPercentage * 100))%.")
            }
        }
    }

    /**
     * Is called when mapbox failes to cache a tile. Mapbox will try to download the tile again, so we don't need to cancel the download.
     */
    @objc func offlinePackDidReceiveError(notification: NSNotification) {
        if let pack = notification.object as? MGLOfflinePack,
            let offlinePackDetails = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(pack.context) as? [String: Any],
            let error = notification.userInfo?[MGLOfflinePackUserInfoKey.error] as? NSError {
            let packName = offlinePackDetails["name"] ?? "unknown"
            print("Offline pack “\(packName)” received error: \(error.localizedFailureReason ?? "unknown error")")
        }
    }

    /**
     * Called when maximum allowed mapbox tiles is reached. For AccuTerra map style we are setting the max tiles count to unlimited.
     * For Mapbox styles, please read Mapbox documentation.
     */
    @objc func offlinePackDidReceiveMaximumAllowedMapboxTiles(notification: NSNotification) {
        if let pack = notification.object as? MGLOfflinePack,
           let offlinePackDetails = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(pack.context) as? [String: Any],
            let maximumCount = (notification.userInfo?[MGLOfflinePackUserInfoKey.maximumCount] as AnyObject).uint64Value {
            let packName = offlinePackDetails["name"] ?? "unknown"
            print("Offline pack “\(packName)” reached limit of \(maximumCount) tiles.")
            self.cacheButton.isSelected = false
            self.progressView.isHidden = true
        }
    }
    
    /**
     * Example how to list all cached regions and their info
     */
    func printListOfOfflinePacks() {
        MGLOfflineStorage.shared.packs?.forEach({ (pack) in
            guard pack.state != .invalid else {
                return
            }
            if let offlinePackDetails = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(pack.context) as? [String: Any] {
                let name = offlinePackDetails["name"] ?? "unknown"
                let style = pack.region.styleURL.absoluteURL
                let size = pack.progress.countOfBytesCompleted
                let resources = pack.progress.countOfResourcesCompleted
                let minx = offlinePackDetails["minx"] as? Double ?? 0
                let miny = offlinePackDetails["miny"] as? Double ?? 0
                let maxx = offlinePackDetails["maxx"] as? Double ?? 0
                let maxy = offlinePackDetails["maxy"] as? Double ?? 0
                debugPrint("name: \(name), style: \(style), size: \(size), resources: \(resources), minx: \(minx), miny: \(miny), maxx: \(maxx), maxy: \(maxy)")
            }
        })
    }

}
