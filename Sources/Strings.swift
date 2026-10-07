import Foundation

// Интерфейс на русском или английском по первому языку системы.
let isRussian = Locale.preferredLanguages.first?.hasPrefix("ru") ?? false

@inline(__always) func L(_ ru: String, _ en: String) -> String { isRussian ? ru : en }

// Подписи встроенных ковров и полов по имени файла без номера.
let builtinNames: [String: (ru: String, en: String)] = [
    "persian": ("Персидский", "Persian"),
    "neuro": ("Нейроковер", "Neural"),
    "soviet": ("Советский", "Soviet"),
    "pixel": ("Пиксельный", "Pixel"),
    "soviet-herringbone": ("Советская елочка", "Soviet herringbone"),
    "soviet-mosaic": ("Советская мозаика", "Soviet mosaic"),
    "oak-planks": ("Дубовые доски", "Oak planks"),
]
