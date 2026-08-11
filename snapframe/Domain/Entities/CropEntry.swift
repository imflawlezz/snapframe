import Foundation

struct CropEntry: Codable, Identifiable, Equatable {
    var id: String { file }
    var file: String
    var timecode: String
    var timecodeSeconds: Double
    var x: Int
    var y: Int
    var size: Int
    var videoWidth: Int
    var videoHeight: Int

    enum CodingKeys: String, CodingKey {
        case file, timecode
        case timecodeSeconds = "timecode_seconds"
        case crop, videoSize = "video_size"
    }

    enum CropKeys: String, CodingKey { case x, y, size }
    enum SizeKeys: String, CodingKey { case width, height }

    init(
        file: String,
        timecode: String,
        timecodeSeconds: Double,
        x: Int,
        y: Int,
        size: Int,
        videoWidth: Int,
        videoHeight: Int
    ) {
        self.file = file
        self.timecode = timecode
        self.timecodeSeconds = timecodeSeconds
        self.x = x
        self.y = y
        self.size = size
        self.videoWidth = videoWidth
        self.videoHeight = videoHeight
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        file = try c.decode(String.self, forKey: .file)
        timecode = try c.decode(String.self, forKey: .timecode)
        timecodeSeconds = try c.decode(Double.self, forKey: .timecodeSeconds)
        let crop = try c.nestedContainer(keyedBy: CropKeys.self, forKey: .crop)
        x = try crop.decode(Int.self, forKey: .x)
        y = try crop.decode(Int.self, forKey: .y)
        size = try crop.decode(Int.self, forKey: .size)
        let vs = try c.nestedContainer(keyedBy: SizeKeys.self, forKey: .videoSize)
        videoWidth = try vs.decode(Int.self, forKey: .width)
        videoHeight = try vs.decode(Int.self, forKey: .height)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(file, forKey: .file)
        try c.encode(timecode, forKey: .timecode)
        try c.encode(timecodeSeconds, forKey: .timecodeSeconds)
        var crop = c.nestedContainer(keyedBy: CropKeys.self, forKey: .crop)
        try crop.encode(x, forKey: .x)
        try crop.encode(y, forKey: .y)
        try crop.encode(size, forKey: .size)
        var vs = c.nestedContainer(keyedBy: SizeKeys.self, forKey: .videoSize)
        try vs.encode(videoWidth, forKey: .width)
        try vs.encode(videoHeight, forKey: .height)
    }
}

struct CropMetadataFile: Codable {
    var source: String
    var sourcePath: String
    var crops: [CropEntry]

    enum CodingKeys: String, CodingKey {
        case source
        case sourcePath = "source_path"
        case crops
    }
}
