import Foundation

enum GestureType: String, CaseIterable, Codable {
    case leftClick = "left_click"
    case rightClick = "right_click"
    case doubleClick = "double_click"
    case drag = "drag"
    case scroll = "scroll"
    case zoom = "zoom"
    case move = "move"
    case pinch = "pinch"
    case swipeLeft = "swipe_left"
    case swipeRight = "swipe_right"
    case swipeUp = "swipe_up"
    case swipeDown = "swipe_down"
    case openHand = "open_hand"
    case closedFist = "closed_fist"
    case peace = "peace"
    case thumbsUp = "thumbs_up"
    case point = "point"
    case wave = "wave"
}
