import UIKit
import SceneKit
import ARKit
import CoreMotion
import CoreLocation



class ViewController: UIViewController, ARSCNViewDelegate {
    lazy var locationManager = CLLocationManager()
    var currentLocation:CLLocation?
    var camCoords = MyCameraCoordinates()
    var sceneView = VirtualObjectARView(frame:.zero)
    var seasonalTilt = SCNNode()
    var celestialEquatorTilt = SCNNode()
    var scene = SCNScene()
    let moMan = CMMotionManager()
    var sunNode = SCNNode()
    var earth:SCNNode?
    var camera = SCNCamera()
    var heading:Float  = 0.0

    var currentGesture: ARGesture?
    let cameraNode = SCNNode()
    
    var bodies = [
        Body(name: "mercury", mass: 0.055, period: 0.24, rotationPeriod: 58.65, distance: 1.0, diameter: 0.382, moons: [], ring: nil),
        Body(name: "venus", mass: 0.815, period: 0.62, rotationPeriod: 243, distance: 1.2, diameter: 0.949, moons: [], ring: nil),
        Body(name: "earth", mass: 1.0, period: 1, rotationPeriod: 1, distance: 1.4, diameter: 30, moons: [
            Moon(name: "moon", image: "art.scnassets/moonTexture.jpg", period: 0.5, size: 0.0025, distance: 0.03)
            ], ring: nil),
        Body(name: "mars", mass: 0.107, period: 1.88, rotationPeriod: 1.03, distance: 2.0, diameter: 0.532, moons: [], ring: nil),
        Body(name: "jupiter", mass: 318, period: 11.86, rotationPeriod: 0.41, distance: 2.4, diameter: 11.209, moons: [], ring: nil),
        Body(name: "saturn", mass: 95, period: 29.46, rotationPeriod: 0.44, distance: 2.8, diameter: 9.44, moons: [], ring: Ring(inner: 0.06, outer: 0.1, height: 0.0001, image: "art.scnassets/saturnRingsTexture.png")),
        Body(name: "uranus", mass: 15, period: 84.01, rotationPeriod: 0.72, distance: 3.2, diameter: 4.007, moons: [], ring: nil),
        Body(name: "neptune", mass: 17, period: 164.8, rotationPeriod: 0.72, distance: 3.6, diameter: 3.883, moons: [], ring: nil)
    ]
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.addSubview(sceneView)
        sceneView.autoresizingMask = [.flexibleWidth,.flexibleHeight]
        sceneView.frame = self.view.bounds
        sceneView.setup()

        let sunSphere = SCNSphere(radius: 0.3)
        sunNode.geometry = sunSphere
        sunNode.geometry?.firstMaterial?.fillMode = .lines
        sunNode.addAnimation(spinAnimation(duration: 40), forKey: "spin")
        sunNode.position = SCNVector3Make(0, 0, 0)
  
        
        celestialEquatorTilt.eulerAngles = SCNVector3(x: 0, y: 0.0, z: -2)
        celestialEquatorTilt.addChildNode(sunNode)
        scene.rootNode.addChildNode(celestialEquatorTilt)
        
        
        for body in bodies {
            
            let sphere = SCNSphere(radius: 0.005 * body.diameter)
             sphere.segmentCount = 30
            sphere.firstMaterial?.diffuse.contents = UIImage(named:"art.scnassets/\(body.name!)Texture.jpg")
            sphere.firstMaterial?.fillMode = .lines
        
            let node = SCNNode()
            node.name = body.name!
            node.geometry = sphere
            node.rotation = SCNVector4(2,4,0,CGFloat.pi / 4)
            if (node.name != "earth"){
                node.addAnimation(spinAnimation(duration: 3 * body.rotationPeriod), forKey: "spin")
                
            }
          
            let rotateAction = SCNAction.rotateAround(center: sunNode.position, radius: 0.5 * body.distance, animationDuration: 10 * body.period)
          
            for moon in body.moons {
                
                let moonSphere = SCNSphere(radius: moon.size)
                moonSphere.firstMaterial?.diffuse.contents = UIImage(named:moon.image)
                let moonNode = SCNNode()
                moonNode.geometry = moonSphere
                moonNode.position = SCNVector3Make(0, 0, 0)
                
                let moonRotateAction = SCNAction.rotateAround(center: SCNVector3(0,0,0), radius: moon.distance, animationDuration: moon.period)
            
                moonNode.runAction(moonRotateAction)
                node.addChildNode(moonNode)
                
            }
            
            node.runAction(rotateAction)
            
            if let ring = body.ring {
                let ringShape = SCNTube(innerRadius: ring.inner, outerRadius: ring.outer, height: ring.height)
                ringShape.firstMaterial?.diffuse.contents = UIImage(named:ring.image)
                
                let ringNode = SCNNode()
                ringNode.geometry = ringShape
                
                node.addChildNode(ringNode)
            }
            
            if (node.name == "earth"){
                

                guard let virtualObjectScene = SCNScene(named: "art.scnassets/SimpleEarth/EarthPlanet.DAE") else {
                    return
                }
                for child in virtualObjectScene.rootNode.childNodes {
                    child.geometry?.firstMaterial?.lightingModel = .physicallyBased
                    node.addChildNode(child)
                   
                }
                node.scale = SCNVector3(0.0001, 0.0001, 0.0001)
               // node.scale = SCNVector3(0.01, 0.01, 0.01)
                //scene.rootNode.addChildNode(node) // nest inside seasonal title
                earth = node
            
                seasonalTilt.addChildNode(node)
                
                // tilt it on it's axis (23.5 degrees), varied by the actual day of the year
                // (note that children nodes are correctly tilted with the parents coordinate space)
                let calendar = Calendar(identifier: .gregorian)
                let dayOfYear = Double( calendar.ordinality(of: .day, in: .year, for: Date())! )
                let daysSinceWinterSolstice = remainder(dayOfYear + 10.0, kDaysInAYear)
                let daysSinceWinterSolsticeInRadians = daysSinceWinterSolstice * 2.0 * Double.pi / kDaysInAYear
                let tiltXRadians = -cos( daysSinceWinterSolsticeInRadians) * kTiltOfEarthsAxisInRadians
                //
                seasonalTilt.eulerAngles = SCNVector3(x: Float(tiltXRadians), y: 0.0, z: 0)
                celestialEquatorTilt.addChildNode(seasonalTilt)
                
                //
             
            }else{
                celestialEquatorTilt.addChildNode(node)
            }
        }
        
        self.sceneView.debugOptions = [.showPhysicsShapes,.showWireframe,.showSkeletons, .showConstraints, .showLightExtents, ARSCNDebugOptions.showFeaturePoints, ARSCNDebugOptions.showWorldOrigin]
        sceneView.showsStatistics = true
        sceneView.delegate = self
        sceneView.scene = scene
        sceneView.scene.lightingEnvironment.intensity = 25
        
      
        
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        
       
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        moMan.deviceMotionUpdateInterval = 1.0/60.0
        
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        // Run the view's session
        sceneView.session.run(configuration)
    
        listenForCoreMotionChanges()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        moMan.stopDeviceMotionUpdates()
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    func spinAnimation(duration: Double) -> CABasicAnimation {

        let spin = CABasicAnimation(keyPath: "rotation")
        
        spin.fromValue = NSValue(scnVector4: SCNVector4(x: 0, y: 1, z: 0, w: 0))
        spin.toValue = NSValue(scnVector4: SCNVector4(x: 0, y: 1, z: 0, w: Float(2 * CGFloat.pi)))
        spin.duration = duration
        spin.repeatCount = .infinity
        
        return spin
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        //lockCameraOnNode(node: earth!)
        //earth?.look(at: sceneView.pointOfView!, offset: nil)
    }

    func lockCameraOnNode(node: SCNNode){
//        let nodePosition = node.presentation.position
        
//        print("current POV:",sceneView.pointOfView?.position)
        
//        print("x:\(nodePosition.x) y:\(nodePosition.y) z:\(nodePosition.z)")
//        node.position = SCNVector3(x: nodePosition.x+80, y: nodePosition.y+80, z: nodePosition.z+80)
        
//        if let cc = camCoords.getCameraCoordinates(sceneView: sceneView){
      //      node.position = SCNVector3(cc.x, cc.y, cc.z)
//        }
        
//        sceneView.pointOfView = node

    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        print(node)
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
    
    func addNodeToSceneView(node:SCNNode,at position: SCNVector3){
        node.position = position
        sceneView.scene.rootNode.addChildNode(node)
    }
    
    func addNodeToPointOfView(node:SCNNode){
        self.sceneView.pointOfView?.addChildNode(node)
    }
    
    func addNodeAtCameraPosition(node:SCNNode){
        if let cc = camCoords.getCameraCoordinates(sceneView: sceneView){
            node.position = SCNVector3(cc.x, cc.y, cc.z)
            sceneView.scene.rootNode.addChildNode(node)
        }
        
    }
    
    func placeNodeInfrontOfCamera(node:SCNNode) {
        let pointOfView = self.sceneView.pointOfView
        node.simdPosition = pointOfView!.simdPosition + (pointOfView?.simdWorldFront)! * 2
        sceneView.scene.rootNode.addChildNode(node)
    }
    
    func constraints(target: SCNNode) -> SCNConstraint {
        let constraint = SCNLookAtConstraint(target: target)
        constraint.isGimbalLockEnabled = true
        return constraint
    }
    
    func setupCamera(constraint: SCNConstraint) {
        let cameraNode = SCNNode()
        let camera = SCNCamera()
        cameraNode.camera = camera
        cameraNode.constraints = [constraint]
    }
    
    func constrainCameraToPlanetNode(_ node:SCNNode){
        // MERGE LOGIC FOR CAMERA FROM https://github.com/dmojdehi/SwiftGlobe
        
        // give us some ambient light (to light the rest of the model)
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.intensity = 20.0 // default is 1000!
        
        //-----------------------------------
        // Setup the camera node itself, which chases after the 'cameraGoal' but is always looking at the globe
        // We use physics to follow the 'camera goal' smoothly
        // (the user manipulates the goal, not the camera!)
        // NB: SCNPhysicsBody requires a shape to be affected by the spring.
        let fakeCameraShape = SCNPhysicsShape(geometry: SCNSphere(radius: 0.001), options: nil)
        let cameraNodePhysics = SCNPhysicsBody(type: .dynamic, shape: fakeCameraShape)
        cameraNodePhysics.isAffectedByGravity = false
        cameraNodePhysics.categoryBitMask = kAffectedBySpring
        cameraNodePhysics.damping = 2.0
        //cameraNodePhysics.velocityFactor = SCNVector3(x:0.8, y:0.8, z: 0.8)
        cameraNode.physicsBody = cameraNodePhysics
        cameraNode.physicsBody?.allowsResting = false
        cameraNode.constraints = [ SCNLookAtConstraint(target: node) ]
        cameraNode.light = ambientLight
        cameraNode.camera = camera
        scene.rootNode.addChildNode(cameraNode)

        
    }
}



