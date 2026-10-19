#!/usr/bin/env swift
import AppKit
import Foundation

// Generates high-DPI 64x64 (@2x) and 32x32 (@1x) rounded-tile brand icons for:
// - Coding Agents: Claude, Codex/OpenAI, OpenCode, Cursor, Grok, Pi, Muse, Gemini, Aider, Ollama
// - App Connectors: GitHub, Linear, Notion, Slack, Gmail, Google Calendar, Jira, Figma, Vercel, Sentry, Supabase, HubSpot

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconsDir = root.appendingPathComponent("Sources/DispatchApp/Resources/Icons")
try FileManager.default.createDirectory(at: iconsDir, withIntermediateDirectories: true)

func savePNG(_ image: NSImage, pixelSize: Int, to url: URL) throws {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { return }
    rep.size = NSSize(width: pixelSize, height: pixelSize)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    image.draw(
        in: NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize),
        from: .zero,
        operation: .copy,
        fraction: 1
    )
    NSGraphicsContext.restoreGraphicsState()
    if let data = rep.representation(using: .png, properties: [:]) {
        try data.write(to: url)
    }
}

func renderTileIcon(
    name: String,
    topColor: NSColor,
    bottomColor: NSColor,
    svgInner: String,
    viewBox: String = "0 0 24 24",
    glyphScale: CGFloat = 0.58
) throws {
    for (pixelSize, suffix) in [(36, ""), (72, "@2x")] {
        let size = CGFloat(pixelSize)
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        let rect = NSRect(x: size * 0.04, y: size * 0.04, width: size * 0.92, height: size * 0.92)
        let path = NSBezierPath(roundedRect: rect, xRadius: size * 0.225, yRadius: size * 0.225)
        let grad = NSGradient(starting: topColor, ending: bottomColor)
        grad?.draw(in: path, angle: -90)

        NSColor.white.withAlphaComponent(0.18).setStroke()
        path.lineWidth = max(1, size * 0.02)
        path.stroke()

        let svgString = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="\(viewBox)" width="256" height="256">
        \(svgInner)
        </svg>
        """
        if let svgData = svgString.data(using: .utf8),
           let glyph = NSImage(data: svgData) {
            let gSize = size * glyphScale
            let gRect = NSRect(
                x: (size - gSize) / 2,
                y: (size - gSize) / 2,
                width: gSize,
                height: gSize
            )
            glyph.draw(in: gRect, from: .zero, operation: .sourceOver, fraction: 1)
        }

        image.unlockFocus()
        try savePNG(image, pixelSize: pixelSize, to: iconsDir.appendingPathComponent("\(name)\(suffix).png"))
    }
}

// 1. Claude Code (Official Anthropic Starburst on Warm Terracotta/Dark Tile)
try renderTileIcon(
    name: "brand-claude",
    topColor: NSColor(calibratedRed: 0.87, green: 0.49, blue: 0.36, alpha: 1),
    bottomColor: NSColor(calibratedRed: 0.76, green: 0.38, blue: 0.26, alpha: 1),
    svgInner: """
    <path fill="#FFFFFF" d="m50.228 170.321 50.357-28.257.843-2.463-.843-1.361h-2.462l-8.426-.518-28.775-.778-24.952-1.037-24.175-1.296-6.092-1.297L0 125.796l.583-3.759 5.12-3.434 7.324.648 16.202 1.101 24.304 1.685 17.629 1.037 26.118 2.722h4.148l.583-1.685-1.426-1.037-1.101-1.037-25.147-17.045-27.22-18.017-14.258-10.37-7.713-5.25-3.888-4.925-1.685-10.758 7-7.713 9.397.649 2.398.648 9.527 7.323 20.35 15.75L94.817 91.9l3.889 3.24 1.555-1.102.195-.777-1.75-2.917-14.453-26.118-15.425-26.572-6.87-11.018-1.814-6.61c-.648-2.723-1.102-4.991-1.102-7.778l7.972-10.823L71.42 0 82.05 1.426l4.472 3.888 6.61 15.101 10.694 23.786 16.591 32.34 4.861 9.592 2.592 8.879.973 2.722h1.685v-1.556l1.36-18.211 2.528-22.36 2.463-28.776.843-8.1 4.018-9.722 7.971-5.25 6.222 2.981 5.12 7.324-.713 4.73-3.046 19.768-5.962 30.98-3.889 20.739h2.268l2.593-2.593 10.499-13.934 17.628-22.036 7.778-8.749 9.073-9.657 5.833-4.601h11.018l8.1 12.055-3.628 12.443-11.342 14.388-9.398 12.184-13.48 18.147-8.426 14.518.778 1.166 2.01-.194 30.46-6.481 16.462-2.982 19.637-3.37 8.88 4.148.971 4.213-3.5 8.62-20.998 5.184-24.628 4.926-36.682 8.685-.454.324.519.648 16.526 1.555 7.065.389h17.304l32.21 2.398 8.426 5.574 5.055 6.805-.843 5.184-12.962 6.611-17.498-4.148-40.83-9.721-14-3.5h-1.944v1.167l11.666 11.406 21.387 19.314 26.767 24.887 1.36 6.157-3.434 4.86-3.63-.518-23.526-17.693-9.073-7.972-20.545-17.304h-1.36v1.814l4.73 6.935 25.017 37.59 1.296 11.536-1.814 3.76-6.481 2.268-7.13-1.297-14.647-20.544-15.1-23.138-12.185-20.739-1.49.843-7.194 77.448-3.37 3.953-7.778 2.981-6.48-4.925-3.436-7.972 3.435-15.749 4.148-20.544 3.37-16.333 3.046-20.285 1.815-6.74-.13-.454-1.49.194-15.295 20.999-23.267 31.433-18.406 19.702-4.407 1.75-7.648-3.954.713-7.064 4.277-6.286 25.47-32.405 15.36-20.092 9.917-11.6-.065-1.686h-.583L44.07 198.125l-12.055 1.555-5.185-4.86.648-7.972 2.463-2.593 20.35-13.999-.064.065Z"/>
    """,
    viewBox: "0 0 256 257",
    glyphScale: 0.62
)

// 2. OpenAI Codex (Official OpenAI Knot)
try renderTileIcon(
    name: "brand-codex",
    topColor: NSColor(calibratedRed: 0.08, green: 0.64, blue: 0.50, alpha: 1),
    bottomColor: NSColor(calibratedRed: 0.05, green: 0.48, blue: 0.37, alpha: 1),
    svgInner: """
    <path fill="#FFFFFF" fill-rule="evenodd" d="M252.794 108.802C289.191 99.0484 326.265 110.305 351.148 135.135C385.113 126.072 422.85 134.862 449.492 161.505C476.136 188.149 484.925 225.888 475.862 259.85V259.854C500.696 284.735 511.95 321.81 502.198 358.207C492.447 394.602 464.161 421.084 430.215 430.217C421.083 464.162 394.603 492.448 358.206 502.199C321.812 511.951 284.734 500.693 259.852 475.864C225.887 484.927 188.15 476.137 161.507 449.495C134.864 422.851 126.073 385.111 135.136 351.149C110.304 326.266 99.0496 289.192 108.801 252.795C118.552 216.4 146.84 189.918 180.784 180.785C189.917 146.841 216.396 118.553 252.794 108.802ZM374.292 407.145C374.292 411.271 372.092 415.086 368.517 417.148L283.723 466.102C302.487 480.585 327.555 486.459 352.217 479.852C386.997 470.532 410.068 439.312 410.555 405.006V317.717C410.555 315.08 409.125 312.621 406.843 311.303L374.292 292.509V407.145ZM251.868 415.897C248.296 417.959 243.893 417.959 240.317 415.897L155.526 366.942C152.366 390.436 159.811 415.08 177.866 433.136H177.863C203.325 458.594 241.896 462.962 271.85 446.232L347.449 402.586C349.735 401.268 351.148 398.8 351.148 396.163V358.579L251.868 415.897ZM368.602 220.628C366.319 219.309 363.474 219.318 361.191 220.637L328.641 239.431L427.921 296.749C431.496 298.811 433.697 302.627 433.697 306.752V404.661C455.622 395.654 473.244 376.881 479.851 352.218C489.169 317.442 473.668 281.85 444.201 264.274L368.602 220.628ZM177.303 206.34C155.377 215.348 137.756 234.122 131.148 258.783C121.832 293.561 137.331 329.153 166.799 346.727L242.398 390.373C244.68 391.692 247.525 391.684 249.807 390.366L282.357 371.572L183.078 314.253C179.504 312.189 177.303 308.375 177.303 304.251V206.34ZM259.849 279.145V331.858L305.5 358.213L351.15 331.858V279.145L305.5 252.789L259.849 279.145ZM327.276 144.9C308.512 130.418 283.445 124.543 258.782 131.15C224.002 140.471 200.931 171.691 200.445 205.995V293.286C200.445 295.923 201.875 298.381 204.158 299.7L236.707 318.493V203.856C236.707 199.731 238.909 195.916 242.483 193.853L327.276 144.9ZM433.137 177.867C407.675 152.407 369.103 148.038 339.149 164.769L263.55 208.415C261.265 209.734 259.852 212.202 259.852 214.838V252.423L359.132 195.105C362.703 193.041 367.108 193.041 370.682 195.105L455.473 244.06C458.635 220.567 451.189 195.922 433.135 177.867H433.137Z"/>
    """,
    viewBox: "100 100 411 411",
    glyphScale: 0.64
)

// 3. OpenCode (Official Geometric Block Logo)
try renderTileIcon(
    name: "brand-opencode",
    topColor: NSColor(calibratedRed: 0.14, green: 0.15, blue: 0.18, alpha: 1),
    bottomColor: NSColor(calibratedRed: 0.08, green: 0.09, blue: 0.11, alpha: 1),
    svgInner: """
    <path d="M24 32H8V16H24V32Z" fill="#FFFFFF" fill-opacity="0.38"/>
    <path d="M24 8H8V32H24V8ZM32 40H0V0H32V40Z" fill="#FFFFFF"/>
    """,
    viewBox: "0 0 32 40",
    glyphScale: 0.56
)

// 4. Cursor Agent (Official 3D Cube Logo)
try renderTileIcon(
    name: "brand-cursor",
    topColor: NSColor(calibratedRed: 0.18, green: 0.19, blue: 0.22, alpha: 1),
    bottomColor: NSColor(calibratedRed: 0.10, green: 0.10, blue: 0.12, alpha: 1),
    svgInner: """
    <path fill="#FFFFFF" d="M457.43,125.94L244.42,2.96c-6.84-3.95-15.28-3.95-22.12,0L9.3,125.94c-5.75,3.32-9.3,9.46-9.3,16.11v247.99c0,6.65,3.55,12.79,9.3,16.11l213.01,122.98c6.84,3.95,15.28,3.95,22.12,0l213.01-122.98c5.75-3.32,9.3-9.46,9.3-16.11v-247.99c0-6.65-3.55-12.79-9.3-16.11h-.01ZM444.05,151.99l-205.63,356.16c-1.39,2.4-5.06,1.42-5.06-1.36v-233.21c0-4.66-2.49-8.97-6.53-11.31L24.87,145.67c-2.4-1.39-1.42-5.06,1.36-5.06h411.26c5.84,0,9.49,6.33,6.57,11.39h-.01Z"/>
    """,
    viewBox: "0 0 466.73 532.09",
    glyphScale: 0.60
)

// 5. Grok Build (Official xAI Orbit/Slash Logo)
try renderTileIcon(
    name: "brand-grok",
    topColor: NSColor(calibratedRed: 0.12, green: 0.12, blue: 0.14, alpha: 1),
    bottomColor: NSColor(calibratedRed: 0.05, green: 0.05, blue: 0.06, alpha: 1),
    svgInner: """
    <path fill="#FFFFFF" d="M9.26905 15.284L17.2479 9.36086C17.6391 9.07047 18.1981 9.18374 18.3845 9.63478C19.3655 12.0135 18.9272 14.8721 16.9755 16.8349C15.0238 18.7976 12.3082 19.228 9.8261 18.2477L7.1146 19.5102C11.0037 22.1834 15.7263 21.5223 18.6774 18.5525C21.0182 16.1985 21.7432 12.9897 21.0653 10.0961L21.0714 10.1023C20.0884 5.85143 21.3131 4.15233 23.8218 0.677913C23.8812 0.595532 23.9406 0.513151 24 0.428711L20.6987 3.74866V3.73836L9.267 15.2861"/>
    <path fill="#FFFFFF" d="M7.62249 16.7237C4.83113 14.0422 5.3124 9.89222 7.69417 7.49905C9.45541 5.72786 12.341 5.00497 14.86 6.06768L17.5653 4.81138C17.0779 4.45714 16.4533 4.07613 15.7365 3.80839C12.4966 2.46764 8.6178 3.13492 5.98413 5.78141C3.45081 8.32904 2.65415 12.2463 4.02219 15.5889C5.04412 18.0871 3.36889 19.8541 1.68137 21.6377C1.08337 22.2699 0.483318 22.9022 0 23.5716L7.62045 16.7257"/>
    """,
    viewBox: "0 0 24 24",
    glyphScale: 0.60
)

// 6. Pi Agent (Official Pixel Pi Logo)
try renderTileIcon(
    name: "brand-pi",
    topColor: NSColor(calibratedRed: 0.48, green: 0.28, blue: 0.88, alpha: 1),
    bottomColor: NSColor(calibratedRed: 0.34, green: 0.18, blue: 0.68, alpha: 1),
    svgInner: """
    <path fill="#FFFFFF" fill-rule="evenodd" d="M165.29 165.29H517.36V400H400V517.36H282.65V634.72H165.29ZM282.65 282.65V400H400V282.65Z"/>
    <path fill="#FFFFFF" d="M517.36 400H634.72V634.72H517.36Z"/>
    """,
    viewBox: "165.29 165.29 469.43 469.43",
    glyphScale: 0.58
)

// 7. Meta Muse Code (Official Meta Infinity Loop)
try renderTileIcon(
    name: "brand-muse",
    topColor: NSColor(calibratedRed: 0.04, green: 0.52, blue: 0.98, alpha: 1),
    bottomColor: NSColor(calibratedRed: 0.02, green: 0.38, blue: 0.86, alpha: 1),
    svgInner: """
    <path fill="#FFFFFF" fill-rule="evenodd" d="M107.9999847,0.0000013c-12.3391113,0-21.984787,9.2935991-30.7164001,21.0993118 C65.2847366,5.821527,55.2499847,0,43.2413788,0C18.7586193,0,0,31.8620682,0,65.5862122 C0,86.6896515,10.2095623,100,27.3103466,100c12.3080502,0,21.1600361-5.8025894,36.8965454-33.3103409 c0,0,6.5597382-11.5841255,11.0725021-19.563858c1.5813522,2.5531845,3.2431107,5.3001404,4.9964676,8.2535095 l7.379303,12.4137955C102.0298843,91.8478851,110.039032,100,124.5517273,100 c16.6595764,0,25.9310303-13.4923325,25.9310303-35.0344849 C150.4827576,29.6551723,131.301178,0.0000013,107.9999847,0.0000013z M52.2068977,59.2413788 c-12.7586212,20-17.1724167,24.4827576-24.2758656,24.4827576c-7.3103428,0-11.6551704-6.4178314-11.6551704-17.8620682 c0-24.4827576,12.2068977-49.5172424,26.7586231-49.5172424c7.880127,0,14.4653816,4.5510426,24.5522308,18.9913158 C58.0087967,50.0272293,52.2068977,59.2413788,52.2068977,59.2413788z M100.3597336,56.7235756L91.5367355,42.00877 c-2.3876724-3.8832092-4.6757278-7.451458-6.8838348-10.7230263 c7.951973-12.273531,14.5113449-18.3891907,22.3126144-18.3891907c16.2069016,0,29.1724243,23.8620682,29.1724243,53.1724091 c0,11.1724167-3.6593475,17.6551743-11.2413864,17.6551743 C117.6294937,83.7241364,114.1578674,78.924736,100.3597336,56.7235756z"/>
    """,
    viewBox: "0 0 150.4828 100",
    glyphScale: 0.62
)

// 8. Google Gemini CLI
try renderTileIcon(
    name: "brand-gemini",
    topColor: NSColor(calibratedRed: 0.25, green: 0.48, blue: 0.96, alpha: 1),
    bottomColor: NSColor(calibratedRed: 0.56, green: 0.32, blue: 0.92, alpha: 1),
    svgInner: """
    <path fill="#FFFFFF" d="M20.2246 10.888C18.6066 10.1911 17.1915 9.23659 15.9769 8.02312C14.7634 6.80966 13.8077 5.39335 13.112 3.7754C12.846 3.15614 12.63 2.51778 12.4653 1.86392C12.4116 1.65034 12.2207 1.5 12 1.5C11.7793 1.5 11.5884 1.65034 11.5347 1.86392C11.37 2.51778 11.1552 3.15375 10.888 3.7754C10.1911 5.39335 9.23659 6.80966 8.02312 8.02312C6.80966 9.2354 5.39335 10.1911 3.7754 10.888C3.15614 11.154 2.51778 11.37 1.86392 11.5347C1.65034 11.5884 1.5 11.7793 1.5 12C1.5 12.2207 1.65034 12.4116 1.86392 12.4653C2.51778 12.63 3.15375 12.8448 3.7754 13.112C5.39335 13.8089 6.80847 14.7634 8.02312 15.9769C9.23659 17.1903 10.1923 18.6066 10.888 20.2246C11.1552 20.8451 11.37 21.4822 11.5347 22.1361C11.5607 22.2399 11.6206 22.332 11.7049 22.3979C11.7891 22.4638 11.893 22.4998 12 22.5C12.2207 22.5 12.4116 22.3497 12.4653 22.1361C12.63 21.4822 12.8448 20.8462 13.112 20.2246C13.8089 18.6066 14.7634 17.1915 15.9769 15.9769C17.1903 14.7634 18.6066 13.8077 20.2246 13.112C20.8451 12.8448 21.4822 12.63 22.1361 12.4653C22.2399 12.4393 22.332 12.3794 22.3979 12.2951C22.4638 12.2109 22.4998 12.107 22.5 12C22.5 11.7793 22.3497 11.5884 22.1361 11.5347C21.4822 11.37 20.8462 11.1552 20.2246 10.888Z"/>
    """,
    viewBox: "0 0 24 24",
    glyphScale: 0.62
)

// 9. Ollama Local (Official Llama Mascot)
try renderTileIcon(
    name: "brand-ollama",
    topColor: NSColor(calibratedRed: 0.22, green: 0.22, blue: 0.25, alpha: 1),
    bottomColor: NSColor(calibratedRed: 0.12, green: 0.12, blue: 0.14, alpha: 1),
    svgInner: """
    <path d="M7 9V5a2 2 0 0 1 4 0v3h2V5a2 2 0 0 1 4 0v4a5 5 0 0 1 2 4v4a4 4 0 0 1-4 4H9a4 4 0 0 1-4-4v-4a5 5 0 0 1 2-4Z" fill="none" stroke="#FFFFFF" stroke-width="2.1" stroke-linecap="round" stroke-linejoin="round"/>
    <circle cx="9.5" cy="13" r="1.2" fill="#FFFFFF"/>
    <circle cx="14.5" cy="13" r="1.2" fill="#FFFFFF"/>
    <path d="M10.5 16.5h3" stroke="#FFFFFF" stroke-width="2.1" stroke-linecap="round"/>
    """,
    viewBox: "0 0 24 24",
    glyphScale: 0.64
)

// 10. Aider (Emerald Terminal Tile)
try renderTileIcon(
    name: "brand-aider",
    topColor: NSColor(calibratedRed: 0.10, green: 0.68, blue: 0.38, alpha: 1),
    bottomColor: NSColor(calibratedRed: 0.06, green: 0.48, blue: 0.26, alpha: 1),
    svgInner: """
    <path d="M4 17l6-6-6-6M12 19h8" fill="none" stroke="#FFFFFF" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>
    """,
    viewBox: "0 0 24 24",
    glyphScale: 0.58
)

// 11. GitHub (Official Octocat)
try renderTileIcon(
    name: "brand-github",
    topColor: NSColor(calibratedRed: 0.18, green: 0.20, blue: 0.23, alpha: 1),
    bottomColor: NSColor(calibratedRed: 0.09, green: 0.10, blue: 0.12, alpha: 1),
    svgInner: """
    <path fill="#FFFFFF" d="M12 0.3C5.4 0.3 0 5.7 0 12.3c0 5.3 3.4 9.8 8.2 11.4.6.1.8-.3.8-.6v-2.2c-3.3.7-4-1.4-4-1.4-.5-1.4-1.3-1.8-1.3-1.8-1.1-.7.1-.7.1-.7 1.2.1 1.8 1.2 1.8 1.2 1.1 1.8 2.8 1.3 3.5 1 .1-.8.4-1.3.8-1.6-2.7-.3-5.5-1.3-5.5-5.9 0-1.3.5-2.4 1.2-3.2-.1-.3-.5-1.5.1-3.2 0 0 1-.3 3.3 1.2 1-.3 2-.4 3-.4s2 .1 3 .4c2.3-1.5 3.3-1.2 3.3-1.2.6 1.7.2 2.9.1 3.2.8.8 1.2 1.9 1.2 3.2 0 4.6-2.8 5.6-5.5 5.9.4.4.8 1.1.8 2.2v3.3c0 .3.2.7.8.6 4.8-1.6 8.2-6.1 8.2-11.4C24 5.7 18.6 0.3 12 0.3z"/>
    """,
    viewBox: "0 0 24 24",
    glyphScale: 0.62
)

// 12. Linear (Official Indigo Diagonal Circle)
try renderTileIcon(
    name: "brand-linear",
    topColor: NSColor(calibratedRed: 0.37, green: 0.42, blue: 0.89, alpha: 1),
    bottomColor: NSColor(calibratedRed: 0.26, green: 0.30, blue: 0.74, alpha: 1),
    svgInner: """
    <circle cx="12" cy="12" r="9.5" fill="none" stroke="#FFFFFF" stroke-width="2.1"/>
    <path d="M5.2 15.8L15.8 5.2M3.8 11.8L11.8 3.8M8.5 19.2L19.2 8.5" stroke="#FFFFFF" stroke-width="2.0" stroke-linecap="round"/>
    """,
    viewBox: "0 0 24 24",
    glyphScale: 0.64
)

// 13. Notion (Monochrome Cube N)
try renderTileIcon(
    name: "brand-notion",
    topColor: NSColor(calibratedRed: 0.18, green: 0.18, blue: 0.19, alpha: 1),
    bottomColor: NSColor(calibratedRed: 0.10, green: 0.10, blue: 0.11, alpha: 1),
    svgInner: """
    <rect x="3" y="3" width="18" height="18" rx="3" fill="none" stroke="#FFFFFF" stroke-width="2.0"/>
    <path d="M8 17V7l8 10V7" fill="none" stroke="#FFFFFF" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>
    """,
    viewBox: "0 0 24 24",
    glyphScale: 0.62
)

// 14. Slack (Aubergine Hash Tile)
try renderTileIcon(
    name: "brand-slack",
    topColor: NSColor(calibratedRed: 0.38, green: 0.12, blue: 0.41, alpha: 1),
    bottomColor: NSColor(calibratedRed: 0.26, green: 0.07, blue: 0.29, alpha: 1),
    svgInner: """
    <rect x="13" y="3" width="3.5" height="8" rx="1.75" fill="#2EB67D"/>
    <rect x="13" y="13" width="8" height="3.5" rx="1.75" fill="#ECB22E"/>
    <rect x="7.5" y="13" width="3.5" height="8" rx="1.75" fill="#E01E5A"/>
    <rect x="3" y="7.5" width="8" height="3.5" rx="1.75" fill="#36C5F0"/>
    """,
    viewBox: "0 0 24 24",
    glyphScale: 0.66
)

// 15. Gmail (Google Red Envelope)
try renderTileIcon(
    name: "brand-gmail",
    topColor: NSColor(calibratedRed: 0.92, green: 0.26, blue: 0.21, alpha: 1),
    bottomColor: NSColor(calibratedRed: 0.78, green: 0.18, blue: 0.14, alpha: 1),
    svgInner: """
    <rect x="2.5" y="4.5" width="19" height="15" rx="2.5" fill="none" stroke="#FFFFFF" stroke-width="2.1"/>
    <path d="M3 6l9 7 9-7" fill="none" stroke="#FFFFFF" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>
    """,
    viewBox: "0 0 24 24",
    glyphScale: 0.62
)

// 16. Google Calendar
try renderTileIcon(
    name: "brand-googlecalendar",
    topColor: NSColor(calibratedRed: 0.16, green: 0.52, blue: 0.96, alpha: 1),
    bottomColor: NSColor(calibratedRed: 0.10, green: 0.38, blue: 0.82, alpha: 1),
    svgInner: """
    <rect x="3" y="4" width="18" height="17" rx="2.5" fill="none" stroke="#FFFFFF" stroke-width="2.1"/>
    <path d="M8 2.5v3M16 2.5v3M3 9.5h18" stroke="#FFFFFF" stroke-width="2.1" stroke-linecap="round"/>
    """,
    viewBox: "0 0 24 24",
    glyphScale: 0.62
)

// 17. Jira (Atlassian Blue)
try renderTileIcon(
    name: "brand-jira",
    topColor: NSColor(calibratedRed: 0.05, green: 0.42, blue: 0.92, alpha: 1),
    bottomColor: NSColor(calibratedRed: 0.02, green: 0.30, blue: 0.74, alpha: 1),
    svgInner: """
    <path fill="#FFFFFF" d="M12.3 3L4 11.3l4.5 4.5 3.8-3.8 3.8 3.8 4.5-4.5L12.3 3zm0 8.2l-3.8 3.8 3.8 3.8 3.8-3.8-3.8-3.8z"/>
    """,
    viewBox: "0 0 24 24",
    glyphScale: 0.64
)

// 18. Figma
try renderTileIcon(
    name: "brand-figma",
    topColor: NSColor(calibratedRed: 0.16, green: 0.16, blue: 0.19, alpha: 1),
    bottomColor: NSColor(calibratedRed: 0.09, green: 0.09, blue: 0.11, alpha: 1),
    svgInner: """
    <path d="M8.5 2h3.5v7H8.5a3.5 3.5 0 0 1 0-7z" fill="#F24E1E"/>
    <path d="M12 2h3.5a3.5 3.5 0 0 1 0 7H12V2z" fill="#FF7262"/>
    <circle cx="15.5" cy="12.5" r="3.5" fill="#1ABCFE"/>
    <path d="M8.5 9h3.5v7H8.5a3.5 3.5 0 0 1 0-7z" fill="#A259FF"/>
    <path d="M8.5 16h3.5v3.5a3.5 3.5 0 1 1-3.5-3.5z" fill="#0ACF83"/>
    """,
    viewBox: "0 0 24 24",
    glyphScale: 0.64
)

// 19. Vercel (Official Black Triangle)
try renderTileIcon(
    name: "brand-vercel",
    topColor: NSColor(calibratedRed: 0.12, green: 0.12, blue: 0.14, alpha: 1),
    bottomColor: NSColor(calibratedRed: 0.04, green: 0.04, blue: 0.05, alpha: 1),
    svgInner: """
    <path fill="#FFFFFF" d="M12 3L22 20H2L12 3z"/>
    """,
    viewBox: "0 0 24 24",
    glyphScale: 0.58
)

// 20. Sentry
try renderTileIcon(
    name: "brand-sentry",
    topColor: NSColor(calibratedRed: 0.36, green: 0.22, blue: 0.56, alpha: 1),
    bottomColor: NSColor(calibratedRed: 0.24, green: 0.14, blue: 0.40, alpha: 1),
    svgInner: """
    <path d="M12 4L3 19h5m4-10l6 10h3L12 4z" fill="none" stroke="#FFFFFF" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>
    """,
    viewBox: "0 0 24 24",
    glyphScale: 0.62
)

// 21. Supabase (Official Emerald Bolt)
try renderTileIcon(
    name: "brand-supabase",
    topColor: NSColor(calibratedRed: 0.14, green: 0.16, blue: 0.15, alpha: 1),
    bottomColor: NSColor(calibratedRed: 0.08, green: 0.10, blue: 0.09, alpha: 1),
    svgInner: """
    <path fill="#3ECF8E" d="M13 2L4 14h7v8l9-12h-7V2z"/>
    """,
    viewBox: "0 0 24 24",
    glyphScale: 0.64
)

// 22. HubSpot (Orange Sprocket)
try renderTileIcon(
    name: "brand-hubspot",
    topColor: NSColor(calibratedRed: 1.0, green: 0.48, blue: 0.35, alpha: 1),
    bottomColor: NSColor(calibratedRed: 0.88, green: 0.34, blue: 0.22, alpha: 1),
    svgInner: """
    <circle cx="12" cy="12" r="4.5" fill="none" stroke="#FFFFFF" stroke-width="2.2"/>
    <circle cx="12" cy="4" r="2" fill="#FFFFFF"/>
    <circle cx="19" cy="16" r="2" fill="#FFFFFF"/>
    <circle cx="5" cy="16" r="2" fill="#FFFFFF"/>
    """,
    viewBox: "0 0 24 24",
    glyphScale: 0.64
)

// 23. Discord
try renderTileIcon(
    name: "brand-discord",
    topColor: NSColor(calibratedRed: 0.35, green: 0.40, blue: 0.95, alpha: 1),
    bottomColor: NSColor(calibratedRed: 0.25, green: 0.30, blue: 0.82, alpha: 1),
    svgInner: """
    <path fill="#FFFFFF" d="M19.3 5.3a16.5 16.5 0 0 0-4.1-1.3l-.5 1.1a15.3 15.3 0 0 0-5.4 0L8.8 4A16.5 16.5 0 0 0 4.7 5.3C2.1 9.2 1.4 13 1.7 16.7a16.6 16.6 0 0 0 5.1 2.6l1.1-1.8a10.7 10.7 0 0 1-1.7-.8l.4-.3a11.8 11.8 0 0 0 10.8 0l.4.3c-.6.3-1.1.6-1.7.8l1.1 1.8a16.6 16.6 0 0 0 5.1-2.6c.4-4.3-.7-8.1-3-11.4zM8.5 14.3c-1 0-1.8-.9-1.8-2s.8-2 1.8-2 1.8.9 1.8 2-.8 2-1.8 2zm7 0c-1 0-1.8-.9-1.8-2s.8-2 1.8-2 1.8.9 1.8 2-.8 2-1.8 2z"/>
    """,
    viewBox: "0 0 24 24",
    glyphScale: 0.64
)

// 24. Stripe
try renderTileIcon(
    name: "brand-stripe",
    topColor: NSColor(calibratedRed: 0.39, green: 0.36, blue: 1.0, alpha: 1),
    bottomColor: NSColor(calibratedRed: 0.28, green: 0.25, blue: 0.86, alpha: 1),
    svgInner: """
    <path fill="#FFFFFF" d="M13.5 9.2c0-.9.8-1.3 2-1.3 1.7 0 3.8.5 5.5 1.5V4.2c-1.8-.7-3.6-1-5.5-1-4.5 0-7.5 2.3-7.5 6.2 0 6.1 8.4 5.1 8.4 7.7 0 1-.9 1.4-2.2 1.4-1.9 0-4.4-.8-6.3-1.9v5.3c2.1.9 4.3 1.3 6.3 1.3 4.6 0 7.8-2.3 7.8-6.2-.1-6.5-8.5-5.4-8.5-7.8z"/>
    """,
    viewBox: "0 0 24 24",
    glyphScale: 0.56
)

// 25. Datadog
try renderTileIcon(
    name: "brand-datadog",
    topColor: NSColor(calibratedRed: 0.45, green: 0.18, blue: 0.68, alpha: 1),
    bottomColor: NSColor(calibratedRed: 0.32, green: 0.10, blue: 0.52, alpha: 1),
    svgInner: """
    <path d="M5 6h8a6 6 0 0 1 0 12H5V6zm4 4v4h4a2 2 0 0 0 0-4H9z" fill="#FFFFFF"/>
    """,
    viewBox: "0 0 24 24",
    glyphScale: 0.62
)

// 26. Asana
try renderTileIcon(
    name: "brand-asana",
    topColor: NSColor(calibratedRed: 0.96, green: 0.38, blue: 0.39, alpha: 1),
    bottomColor: NSColor(calibratedRed: 0.84, green: 0.25, blue: 0.28, alpha: 1),
    svgInner: """
    <circle cx="12" cy="6.5" r="3.8" fill="#FFFFFF"/>
    <circle cx="6.5" cy="16.2" r="3.8" fill="#FFFFFF"/>
    <circle cx="17.5" cy="16.2" r="3.8" fill="#FFFFFF"/>
    """,
    viewBox: "0 0 24 24",
    glyphScale: 0.64
)

// 27. Trello
try renderTileIcon(
    name: "brand-trello",
    topColor: NSColor(calibratedRed: 0.04, green: 0.48, blue: 0.88, alpha: 1),
    bottomColor: NSColor(calibratedRed: 0.02, green: 0.35, blue: 0.72, alpha: 1),
    svgInner: """
    <rect x="4" y="4" width="6.5" height="15" rx="1.5" fill="#FFFFFF"/>
    <rect x="13.5" y="4" width="6.5" height="10" rx="1.5" fill="#FFFFFF"/>
    """,
    viewBox: "0 0 24 24",
    glyphScale: 0.62
)

// 28. Cloudflare
try renderTileIcon(
    name: "brand-cloudflare",
    topColor: NSColor(calibratedRed: 0.96, green: 0.52, blue: 0.14, alpha: 1),
    bottomColor: NSColor(calibratedRed: 0.86, green: 0.38, blue: 0.06, alpha: 1),
    svgInner: """
    <path fill="#FFFFFF" d="M17.5 18H6.8a4.3 4.3 0 0 1-.5-8.5 6 6 0 0 1 11.4-1.3A3.8 3.8 0 0 1 17.5 18z"/>
    """,
    viewBox: "0 0 24 24",
    glyphScale: 0.66
)

print("Generated 28 brand icons (1x and 2x)")
