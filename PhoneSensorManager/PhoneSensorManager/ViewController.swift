//
//  ViewController.swift
//  PhoneSensorManager
//
//  Created by Larry Li on 12/11/19.
//  Copyright © 2019 e-motion.ai. All rights reserved.
//
//
import UIKit
import Charts
import SceneKit
import Euclid
import CoreMotion
import Foundation


class ViewController: UIViewController {

    @IBOutlet weak var lineChartView: LineChartView!
    @IBOutlet weak var sceneView: SCNView!
    @IBOutlet weak var graphPickView: UIPickerView!
    @IBOutlet weak var exportFileName: UITextField!
    @IBOutlet weak var recordButton: UIButton!
    
    // Line chart related params
    let dataSize : Int = 100
    var fifo : Fifo<(Double, Double, Double)>!
            
    // Reference frames display params
    var scene = SCNScene()
    var cameraNode = SCNNode()
    var geometry : SCNGeometry!
    var phoneRefFrameNode : SCNNode!
    var earthRefFrameNode : SCNNode!
    var carRefFrameNode : SCNNode!
    var phoneRefFrame : Mesh!
    var earthRefFrame : Mesh!
    var carRefFrame : Mesh!
    let sensor = SensorManager()

    // UI params
    var defaultColor : UIColor!
    var graphIndex : Int = 0
    var pickerData = [
        "Reference frames",
        "Acceleration",
        "Speed"]
    
    
     override func viewDidLoad() {
        super.viewDidLoad()
        
        fifo = Fifo<(Double, Double, Double)>(dataSize, invalid: (0,0,0))
        
        recordButton.setTitle("Record", for: .normal)
        defaultColor = recordButton.titleColor(for: .normal)
        
        // Set up graph picker
        graphPickView.delegate = self
        graphPickView.dataSource = self
        
        // Setup reference frame display
        setupRefFrameView()
        
        // Setup chart display
        setupLineChartView()
        
        // Setup periodic timer task
        _ = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(periodic), userInfo: nil, repeats: true)
    }
    
    @IBAction func onClearPressed(_ sender: Any) {
    }
    
    @IBAction func onExportPressed(_ sender: Any) {
    }
    
    @IBAction func onRecordToggled(_ sender: Any) {
        if recordButton.titleLabel?.text == "Record" {
            recordButton.setTitleColor(UIColor.red, for: .normal)
            recordButton.setTitle("Stop", for: .normal)
        }
        else {
            recordButton.setTitleColor(defaultColor, for: .normal)
            recordButton.setTitle("Record", for: .normal)
        }
    }
    
    @objc func periodic() {
        fifo.push((sensor.data.accelX, sensor.data.accelY, sensor.data.accelZ))
        if !sceneView.isHidden {
            updateScene()
        }
        else {
            updateChartData()
        }
    }
    
    func updateChartData() {
            
        // Create the data collection [ChartDataEntry]
        let buf = fifo.get()
        var xData : [ChartDataEntry] = []
        var yData: [ChartDataEntry] = []
        var zData : [ChartDataEntry] = []
        for i in 0..<buf.count {
            let x = Double(i)
            let yx = buf[i].0
            let yy = buf[i].1
            let yz = buf[i].2
            xData.append(ChartDataEntry(x: x, y: Double(yx)))
            yData.append(ChartDataEntry(x: x, y: Double(yy)))
            zData.append(ChartDataEntry(x: x, y: Double(yz)))
        }
        
        // Setup the data set object
        let xSet = LineChartDataSet(entries: xData, label: "X")
        xSet.axisDependency = .left
        xSet.setColor(UIColor.red)
        xSet.lineWidth = 1.5
        xSet.drawCirclesEnabled = false
        xSet.drawValuesEnabled = false
        xSet.fillAlpha = 0.26
        xSet.fillColor = UIColor(red: 51/255, green: 181/255, blue: 229/255, alpha: 1)
        xSet.highlightColor = UIColor(red: 244/255, green: 117/255, blue: 117/255, alpha: 1)
        xSet.drawCircleHoleEnabled = false
    
        let ySet = LineChartDataSet(entries: yData, label: "Y")
        ySet.axisDependency = .left
        ySet.setColor(UIColor.green)
        ySet.lineWidth = 1.5
        ySet.drawCirclesEnabled = false
        ySet.drawValuesEnabled = false
        ySet.fillAlpha = 0.26
        ySet.fillColor = UIColor(red: 51/255, green: 181/255, blue: 229/255, alpha: 1)
        ySet.highlightColor = UIColor(red: 244/255, green: 117/255, blue: 117/255, alpha: 1)
        ySet.drawCircleHoleEnabled = false
        
        let zSet = LineChartDataSet(entries: zData, label: "Z")
        zSet.axisDependency = .left
        zSet.setColor(UIColor.blue)
        zSet.lineWidth = 1.5
        zSet.drawCirclesEnabled = false
        zSet.drawValuesEnabled = false
        zSet.fillAlpha = 0.26
        zSet.fillColor = UIColor(red: 51/255, green: 181/255, blue: 229/255, alpha: 1)
        zSet.highlightColor = UIColor(red: 244/255, green: 117/255, blue: 117/255, alpha: 1)
        zSet.drawCircleHoleEnabled = false
        
        // Setup the LineChartData
        let data = LineChartData(dataSets: [xSet, ySet, zSet])
        data.setValueTextColor(.white)
        data.setValueFont(.systemFont(ofSize: 9, weight: .light))
        
        // Give the data to lineChartView
        lineChartView.data = data
    }

}


// ViewController LineChartView support functions
extension ViewController {
    
    func setupLineChartView() {
        // General settings
        lineChartView.delegate = self
        lineChartView.chartDescription?.enabled = false
        lineChartView.dragEnabled = true
        lineChartView.setScaleEnabled(true)
        lineChartView.pinchZoomEnabled = false
        lineChartView.highlightPerDragEnabled = true
        lineChartView.backgroundColor = .white
        lineChartView.legend.enabled = false
               
        let xAxis = lineChartView.xAxis
        xAxis.labelPosition = .topInside
        xAxis.labelFont = .systemFont(ofSize: 12, weight: .light)
        xAxis.labelTextColor = UIColor.black
        xAxis.drawAxisLineEnabled = false
        xAxis.drawGridLinesEnabled = false
        xAxis.centerAxisLabelsEnabled = true
        xAxis.granularity = 1 // milliseconds
        xAxis.valueFormatter = IntAxisValueFormatter()

        // Setup Y axis
        let leftAxis = lineChartView.leftAxis
        leftAxis.labelPosition = .insideChart
        leftAxis.labelFont = .systemFont(ofSize: 12, weight: .light)
        leftAxis.drawGridLinesEnabled = true
        leftAxis.granularityEnabled = true
        leftAxis.axisMinimum = -10
        leftAxis.axisMaximum = 10
        leftAxis.yOffset = 0
        leftAxis.labelTextColor = UIColor.red

        lineChartView.rightAxis.enabled = false
        lineChartView.legend.form = .line
    }
}

// ChartViewDelegate
extension ViewController : ChartViewDelegate {
    @objc func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight: Highlight) {
        print("Data at X(\(entry.x)) = \(entry.y)")
    }
       
    // Called when a user stops panning between values on the chart
    @objc func chartViewDidEndPanning(_ chartView: ChartViewBase) {
    }
       
    // Called when nothing has been selected or an "un-select" has been made.
    @objc func chartValueNothingSelected(_ chartView: ChartViewBase) {
    }
       
    // Callbacks when the chart is scaled / zoomed via pinch zoom gesture.
    @objc func chartScaled(_ chartView: ChartViewBase, scaleX: CGFloat, scaleY: CGFloat) {
    }
       
    // Callbacks when the chart is moved / translated via drag gesture.
    @objc func chartTranslated(_ chartView: ChartViewBase, dX: CGFloat, dY: CGFloat) {
    }

    // Callbacks when Animator stops animating
    @objc func chartView(_ chartView: ChartViewBase, animatorDidStop animator: Animator) {
    }
}

// ViewController Scene support functions
extension ViewController {
    func setupRefFrameView() {
        // Setup scene and camera
        cameraNode.camera = SCNCamera()
        scene.rootNode.addChildNode(cameraNode)
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 3.0)
        
        // Create ref frames
        phoneRefFrame = refFrame(size: 2.0, alpha: 0.2)
        earthRefFrame = refFrame(size: 2.0, alpha: 0.6)
        carRefFrame = refFrame(size: 2.0, alpha: 1.0)

        // Add phone ref frame
        geometry = SCNGeometry(phoneRefFrame) {
            let material = SCNMaterial()
            material.diffuse.contents = $0 as? UIColor
            return material
        }
        phoneRefFrameNode = SCNNode(geometry: geometry)
        scene.rootNode.addChildNode(phoneRefFrameNode)

        // Add earth ref frame
        geometry = SCNGeometry(earthRefFrame) {
            let material = SCNMaterial()
            material.diffuse.contents = $0 as? UIColor
            return material
        }
        earthRefFrameNode = SCNNode(geometry: geometry)
        scene.rootNode.addChildNode(earthRefFrameNode)

        // Add car ref frame
        geometry = SCNGeometry(carRefFrame) {
            let material = SCNMaterial()
            material.diffuse.contents = $0 as? UIColor
            return material
        }
        carRefFrameNode = SCNNode(geometry: geometry)
        scene.rootNode.addChildNode(carRefFrameNode)
        
        // configure the SCNView
        sceneView.scene = scene
        sceneView.autoenablesDefaultLighting = true
        sceneView.allowsCameraControl = false
        sceneView.showsStatistics = false
        sceneView.backgroundColor = .white
    }
    
    func drawEarthRefFrame(r: CMRotationMatrix) {
        let arg = 1 + r.m11 + r.m22 + r.m33
        if arg > 0.0000001 {
            let qw = sqrt(arg)/2
            let qx = (r.m32 - r.m23) / (4*qw)
            let qy = (r.m13 - r.m31) / (4*qw)
            let qz = (r.m21 - r.m12) / (4*qw)
            earthRefFrameNode.orientation = SCNQuaternion(qx, qy, qz, qw)
        }
    }
    
    func drawCarRefFrame(r: CMRotationMatrix) {
        let arg = 1 + r.m11 + r.m22 + r.m33
        if arg > 0.0000001 {
            let qw = sqrt(arg)/2
            let qx = (r.m32 - r.m23) / (4*qw)
            let qy = (r.m13 - r.m31) / (4*qw)
            let qz = (r.m21 - r.m12) / (4*qw)
            carRefFrameNode.orientation = SCNQuaternion(qx, qy, qz, qw)
        }
    }
    
    func updateScene() {
        let speed = sensor.data.speed
        let course = sensor.data.course
        var RotationCP : CMRotationMatrix
        let RotationGP = sensor.rotationMatrix
        
        SCNTransaction.begin()
        if course > 0 && speed > 2.2452 {
            let theta = -course / 180.0 * Double.pi
            let c = cos(theta)
            let s = sin(theta)
            let RotationGC = CMRotationMatrix(m11: c, m12:-s, m13: 0,
                                              m21: s, m22: c, m23: 0,
                                              m31: 0, m32: 0, m33: 1)
            RotationCP = RotationGP * RotationGC
        }
        else {
            RotationCP = CMRotationMatrix().identity()
        }
        drawCarRefFrame(r: RotationCP)
        drawEarthRefFrame(r: RotationGP)
        SCNTransaction.commit()
    }
    
    func arrow(length: Double, color: UIColor) -> Mesh {
        let tip = Mesh.cone(radius:0.1, height:0.4, material: color)
        let rod = Mesh.cylinder(radius: 0.05, height: length, material: color)
        let mesh = rod.merge(tip.translated(by: Vector(0.0, length/2.0, 0.0) ))
        return mesh
    }

    func refFrame(size: Double, alpha: Double)-> Mesh {
        let axisX = arrow(length: size, color: UIColor(red: 1, green: 0, blue: 0, alpha: CGFloat(alpha))).rotZ(deg: 90)
        let axisY = arrow(length: size, color: UIColor(red: 0, green: 1, blue: 0, alpha: CGFloat(alpha)))
        let axisZ = arrow(length: size, color: UIColor(red: 0, green: 0, blue: 1, alpha: CGFloat(alpha))).rotX(deg: -90)
        return axisX.merge(axisY.merge(axisZ))
    }
}



// UIPickerViewDelegate, UIPickerViewDataSource extension
extension ViewController : UIPickerViewDelegate, UIPickerViewDataSource {
    // Number of columns of data
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    // The number of rows of data
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return pickerData.count
    }
    
    // The data to return fopr the row and component (column) that's being passed in
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return pickerData[row]
    }
    
    // Capture the picker view selection
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        graphIndex = row
        sceneView.isHidden = (graphIndex != 0)
        switch graphIndex {
        case 0:
            title = "Reference Frames"
        case 1:
            title = "Accelerations"
        case 2:
            title = "Speed"
        default:
            break
        }
    }
}
