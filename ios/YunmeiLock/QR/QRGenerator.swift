import UIKit
import CoreImage

enum QRGenerator {
    static func image(_ text:String,size:CGFloat) -> UIImage? {
        guard size>0,let filter=CIFilter(name:"CIQRCodeGenerator") else { return nil }
        filter.setValue(Data(text.utf8),forKey:"inputMessage")
        filter.setValue("M",forKey:"inputCorrectionLevel")
        guard let output=filter.outputImage else { return nil }
        let quietZone:CGFloat=4
        let scale=max(1,floor(size/(output.extent.width+quietZone*2)))
        let image=output.transformed(by:CGAffineTransform(scaleX:scale,y:scale))
        let extent=image.extent.insetBy(dx:-quietZone*scale,dy:-quietZone*scale)
        let background=CIImage(color:CIColor.white).cropped(to:extent)
        guard let bitmap=CIContext().createCGImage(image.composited(over:background),from:extent) else { return nil }
        return UIImage(cgImage:bitmap)
    }
}
