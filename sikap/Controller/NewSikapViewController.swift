//
//  NewSikapViewController.swift
//  sikap
//
//  Created by Michael Tadeo on 5/25/19.
//  Copyright © 2019 Tadeo Man. All rights reserved.
//

import UIKit
import MapKit
import AddressBook
import Firebase
import AWSUserPoolsSignIn

class NewSikapViewController: UIViewController {
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var clearButton: UIButton!
    @IBOutlet weak var endButton: UIButton!
    @IBOutlet weak var sikapDetailsLabel: UILabel!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet var nameLabel: UILabel!
    
    private var distance = Measurement(value: 0, unit: UnitLength.miles)
    private var locationList: [CLLocation] = []
    private let locationManager = CLLocationManager()
    private var directionLine: MKPolyline?
    private var sikapLine: MKPolyline?
    
    let distanceFormatter = MeasurementFormatter()
    let dateFormatter = DateFormatter()
    let user = AWSCognitoUserPoolsSignInProvider.sharedInstance()
        .getUserPool()
        .currentUser()?
        .username
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        retrieveName()
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationList.removeAll()
        checkLocationAuthorization()
        dateFormatter.dateStyle = .medium
        zoomOut()
    }
    
    func checkLocationAuthorization() {
        switch CLLocationManager.authorizationStatus() {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            setupLocationManager()
            break
        case .authorizedAlways:
            setupLocationManager()
            break
        case .restricted:
            let alertController = UIAlertController(title: "Restricted Access",
                                                    message: "Sorry. You do not have permission to configure this iPhone's settings.",
                                                    preferredStyle: .actionSheet)
            alertController.addAction(UIAlertAction(title: "Ok", style: .cancel))
            break
        case .denied:
            let alertController = UIAlertController(title: "Please allow access to current location",
                                                    message: "Go to your iPhone's Settings, scroll down & tap Sikap, tap Location, then tap - While Using the App.",
                                                    preferredStyle: .actionSheet)
            alertController.addAction(UIAlertAction(title: "Ok", style: .cancel))
            break
        @unknown default:
            break
        }
    }
    
    func setupLocationManager() {
        locationManager.delegate = self
        locationManager.activityType = .fitness
        locationManager.distanceFilter = 8
        locationManager.startUpdatingLocation()
    }
    
    @IBAction func clearButtonTapped(_ sender: Any) {
        clearDirections()
        searchBar.text = nil
    }
    
    func clearDirections () {
        
        //Hide Keyboard
        searchBar.resignFirstResponder()
        dismiss(animated: true, completion: nil)
        
        if directionLine != nil {
            mapView.removeOverlay(directionLine!)
            let annotations = mapView.annotations
            mapView.removeAnnotations(annotations)
        }
    }
    
    @IBAction func endButtonTapped(_ sender: Any) {
        
        let alertController = UIAlertController(title: "Ending Sikap",
                                                message: "Are you sure?",
                                                preferredStyle: .actionSheet)
        
        alertController.addAction(UIAlertAction(title: "Continue", style: .cancel))
        
        alertController.addAction(UIAlertAction(title: "End", style: .default) { _ in
            
            let date = self.dateFormatter.string(from: Date())
            let distance = self.distanceFormatter.string(from: self.distance)
            self.clearDirections()
            self.updateDisplay()
            self.locationManager.stopUpdatingLocation()
            self.sikapDetailsLabel.text = ("\(date) - Distance: \(distance)")
            
            if self.locationManager.location?.coordinate != nil {
                guard self.sikapLine != nil else {return}
                self.mapView.setVisibleMapRect(self.sikapLine!.boundingMapRect, animated: true)
            }
        })
        
        alertController.addAction(UIAlertAction(title: "Discard", style: .destructive) { _ in
            self.locationManager.stopUpdatingLocation()
            _ = self.navigationController?.popToRootViewController(animated: true)
        })
        
        DispatchQueue.main.async {
            self.present(alertController, animated: true)
        }
    }
    
    private func retrieveName() {
        
        let profileDB = Database.database().reference()
        profileDB.child("\(user!)/name").observeSingleEvent(of: .value)
        {(snapshot) in
            let name = snapshot.value as? String
            guard name != nil else {return}
            self.nameLabel.text = "\(name!)'s Sikap Progress"
        }
        
        DispatchQueue.main.async {
            self.nameLabel.reloadInputViews()
        }
    }
    
    private func updateDisplay() {
        endButton.isHidden = true
        searchBar.isHidden = true
        clearButton.isHidden = true
        saveButton.isHidden = false
        sikapDetailsLabel.isHidden = false
        nameLabel.isHidden = false
    }
    
    //Post Details to Firebase Database
    @IBAction func saveButtonTapped(_ sender: Any) {

        saveButton.isHidden = true
    
        let date = dateFormatter.string(from: Date())
        let distance = distanceFormatter.string(from: self.distance)
        
        let sikapDetailsDB = Database.database().reference().child(user!)
        let sikapDictionary = ["date": date, "distance": distance]
        
        sikapDetailsDB.childByAutoId().setValue(sikapDictionary) {
            (error, ref) in
            if error != nil {
                print(error!)
            }
            else {
                print("Sikap saved successfully")
            }
        }
        
        //Take a screenshot for shareable image of details
        let screenshot = self.view.takeScreenShot()
        image = screenshot
        performSegue(withIdentifier: "ScreenShotSegue", sender: nil)
    }
}

extension NewSikapViewController: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for newLocation in locations {
            let recentLocation = newLocation.timestamp.timeIntervalSinceNow
            guard newLocation.horizontalAccuracy < 20 && abs(recentLocation) < 10 else { continue }
            
            if let lastLocation = locationList.last {
                let triangulation = newLocation.distance(from: lastLocation)
                distance = distance + Measurement(value: triangulation, unit: UnitLength.meters)
                let coordinates = [lastLocation.coordinate, newLocation.coordinate]
                
                let sikapPolyLine = MKPolyline(coordinates: coordinates, count: 2)
                sikapLine = sikapPolyLine
                mapView.addOverlay(sikapPolyLine)
                
                //mapView.addOverlay(MKPolyline(coordinates: coordinates, count: 2))
                let region = MKCoordinateRegion.init(center: newLocation.coordinate, latitudinalMeters: 200, longitudinalMeters: 200)
                mapView.setRegion(region, animated: true)
            }
            locationList.append(newLocation)
        }
    }
}

extension NewSikapViewController: MKMapViewDelegate {
    
    func zoomOut () {
        let coordinates:CLLocationCoordinate2D = CLLocationCoordinate2DMake(0, 0)
        let region = MKCoordinateRegion.init(center: coordinates, latitudinalMeters: 19903100, longitudinalMeters: 19903100)
        mapView.setRegion(region, animated: true)
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        guard let polyline = overlay as? MKPolyline else {
            return MKOverlayRenderer(overlay: overlay)
        }
        if overlay as? MKPolyline == directionLine {
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = .green
            renderer.lineWidth = 3
            return renderer
            
        } else if overlay as? MKPolyline == sikapLine {
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = .cyan
            renderer.lineWidth = 5
            return renderer
        }
        return MKPolylineRenderer(polyline: polyline)
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        checkLocationAuthorization()
    }
}

extension NewSikapViewController: UISearchBarDelegate {
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        clearDirections()
        
        //Create search request
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = searchBar.text
        
        let activeSearch = MKLocalSearch(request: searchRequest)
        activeSearch.start { (response, error) in
            
            if response == nil { print("Search Error") }
                
            else {
                
                //Get data
                let latitude = response?.boundingRegion.center.latitude
                let longitude = response?.boundingRegion.center.longitude
                
                //Create annotation
                let annotation = MKPointAnnotation()
                annotation.title = searchBar.text
                annotation.coordinate = CLLocationCoordinate2DMake(latitude!, longitude!)
                self.mapView.addAnnotation(annotation)
                
                //Zoom in on annotation
                let coordinates:CLLocationCoordinate2D = CLLocationCoordinate2DMake(latitude!, longitude!)
                let span = MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
                let region = MKCoordinateRegion(center: coordinates, span: span)
                self.mapView.setRegion(region, animated: true)
                
                //Alert if location is not found
                guard let location = self.locationManager.location?.coordinate else {
                    let alertController = UIAlertController(title: "Current Location Not Found!",
                                                            message: "Please move to a spot with better signal & make sure location services are enabled.",
                                                            preferredStyle: .actionSheet)
                    alertController.addAction(UIAlertAction(title: "Ok", style: .cancel))
                    return
                }
                
                //Show direction by adding a line from current location to search result
                let startingLocation = MKPlacemark(coordinate: location)
                let destination = MKPlacemark(coordinate: coordinates)
                let request = MKDirections.Request()
                request.source = MKMapItem(placemark: startingLocation)
                request.destination = MKMapItem(placemark: destination)
                request.transportType = .walking
                let directions = MKDirections(request: request)
                directions.calculate { [unowned self] (response, error) in
                    
                    guard let response = response else {
                        let alertController = UIAlertController(title: "Location Not Found!",
                                                                message: "Please move to a spot with better signal & make sure location services are enabled.",
                                                                preferredStyle: .actionSheet)
                        alertController.addAction(UIAlertAction(title: "Ok", style: .cancel))
                        return
                    }
                    
                    for route in response.routes {
                        let directionPolyLine = route.polyline
                        self.directionLine = directionPolyLine
                        self.mapView.addOverlay(directionPolyLine)
                        self.mapView.setVisibleMapRect(directionPolyLine.boundingMapRect, animated: true)
                    }
                }
            }
        }
    }
}

extension UIView {
    func takeScreenShot () -> UIImage {
        UIGraphicsBeginImageContextWithOptions(self.bounds.size, false, UIScreen.main.scale)
        drawHierarchy(in: self.bounds, afterScreenUpdates: true)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        if image != nil {
            return image!
        }
        return UIImage()
    }
}
