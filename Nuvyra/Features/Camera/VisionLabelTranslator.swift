import Foundation

/// Core ML / Vision modellerinden gelen ham etiketleri (tipik olarak
/// İngilizce ve `snake_case` veya boşluklu) Türkçe gıda terimlerine çevirir.
/// Sözlükte karşılığı olmayanlar capitalized ham form ile geri döner —
/// böylece kullanıcı hiçbir zaman "hot_dog" gibi yapay bir ip görmez.
enum VisionLabelTranslator {
    /// Anahtarlar mutlaka lowercase + boşluklu olmalı; normalize edici
    /// fonksiyon `_` karakterlerini boşluğa çevirir.
    /// Apple'ın `VNClassifyImageRequest` taksonomisi + COCO + yaygın Türk
    /// mutfağı terimleri için manuel kurulmuştur.
    private static let dictionary: [String: String] = [
        // Meyveler
        "apple": "Elma",
        "banana": "Muz",
        "orange": "Portakal",
        "lemon": "Limon",
        "lime": "Misket limonu",
        "pear": "Armut",
        "peach": "Şeftali",
        "apricot": "Kayısı",
        "plum": "Erik",
        "strawberry": "Çilek",
        "raspberry": "Ahududu",
        "blueberry": "Yaban mersini",
        "blackberry": "Böğürtlen",
        "grape": "Üzüm",
        "watermelon": "Karpuz",
        "melon": "Kavun",
        "pineapple": "Ananas",
        "mango": "Mango",
        "kiwi": "Kivi",
        "pomegranate": "Nar",
        "cherry": "Kiraz",
        "fig": "İncir",
        "avocado": "Avokado",
        "coconut": "Hindistan cevizi",
        "date": "Hurma",

        // Sebzeler
        "tomato": "Domates",
        "potato": "Patates",
        "sweet potato": "Tatlı patates",
        "onion": "Soğan",
        "garlic": "Sarımsak",
        "carrot": "Havuç",
        "broccoli": "Brokoli",
        "cauliflower": "Karnabahar",
        "cucumber": "Salatalık",
        "pepper": "Biber",
        "bell pepper": "Dolmalık biber",
        "chili pepper": "Acı biber",
        "spinach": "Ispanak",
        "lettuce": "Marul",
        "arugula": "Roka",
        "cabbage": "Lahana",
        "eggplant": "Patlıcan",
        "zucchini": "Kabak",
        "pumpkin": "Bal kabağı",
        "corn": "Mısır",
        "mushroom": "Mantar",
        "olive": "Zeytin",
        "olives": "Zeytin",
        "leek": "Pırasa",
        "celery": "Kereviz",
        "artichoke": "Enginar",
        "okra": "Bamya",
        "asparagus": "Kuşkonmaz",

        // Tahıllar & ekmek
        "bread": "Ekmek",
        "white bread": "Beyaz ekmek",
        "whole wheat bread": "Tam buğday ekmeği",
        "bagel": "Simit",
        "croissant": "Kruvasan",
        "toast": "Kızarmış ekmek",
        "pita": "Pide ekmeği",
        "tortilla": "Tortilla",
        "rice": "Pilav",
        "fried rice": "Kıymalı pilav",
        "pasta": "Makarna",
        "noodle": "Erişte",
        "noodles": "Erişte",
        "spaghetti": "Spagetti",
        "lasagna": "Lazanya",
        "couscous": "Kuskus",
        "bulgur": "Bulgur",
        "oats": "Yulaf",
        "oatmeal": "Yulaf ezmesi",
        "cereal": "Mısır gevreği",
        "granola": "Granola",

        // Protein
        "egg": "Yumurta",
        "fried egg": "Sahanda yumurta",
        "boiled egg": "Haşlanmış yumurta",
        "omelette": "Omlet",
        "chicken": "Tavuk",
        "grilled chicken": "Izgara tavuk",
        "fried chicken": "Kızarmış tavuk",
        "beef": "Sığır eti",
        "veal": "Dana eti",
        "lamb": "Kuzu eti",
        "pork": "Domuz eti",
        "fish": "Balık",
        "salmon": "Somon",
        "tuna": "Ton balığı",
        "anchovy": "Hamsi",
        "sardine": "Sardalye",
        "trout": "Alabalık",
        "shrimp": "Karides",
        "prawn": "Karides",
        "calamari": "Kalamar",
        "octopus": "Ahtapot",
        "meatball": "Köfte",
        "sausage": "Sucuk",
        "salami": "Salam",
        "bacon": "Pastırma",
        "ham": "Jambon",
        "steak": "Biftek",
        "tofu": "Tofu",
        "lentil": "Mercimek",
        "lentils": "Mercimek",
        "chickpea": "Nohut",
        "chickpeas": "Nohut",
        "bean": "Fasulye",
        "beans": "Fasulye",

        // Süt ürünleri
        "milk": "Süt",
        "cheese": "Peynir",
        "feta cheese": "Beyaz peynir",
        "yogurt": "Yoğurt",
        "butter": "Tereyağı",
        "cream": "Krema",
        "kefir": "Kefir",

        // Hazır yemekler
        "pizza": "Pizza",
        "hamburger": "Hamburger",
        "burger": "Hamburger",
        "cheeseburger": "Çizburger",
        "hot dog": "Sosisli sandviç",
        "sandwich": "Sandviç",
        "salad": "Salata",
        "caesar salad": "Sezar salata",
        "soup": "Çorba",
        "lentil soup": "Mercimek çorbası",
        "stew": "Yahni",
        "curry": "Köri",
        "sushi": "Suşi",
        "ramen": "Ramen",
        "taco": "Tako",
        "burrito": "Burrito",
        "wrap": "Dürüm",
        "dumpling": "Mantı",
        "kebab": "Kebap",
        "doner": "Döner",
        "donair": "Döner",
        "lahmacun": "Lahmacun",
        "pide": "Pide",
        "manti": "Mantı",
        "dolma": "Dolma",
        "borek": "Börek",
        "baklava": "Baklava",
        "kunefe": "Künefe",
        "menemen": "Menemen",
        "shawarma": "Şavarma",
        "falafel": "Falafel",
        "hummus": "Humus",

        // Atıştırmalık & tatlı
        "cake": "Kek",
        "cupcake": "Cupcake",
        "cookie": "Kurabiye",
        "biscuit": "Bisküvi",
        "donut": "Donut",
        "doughnut": "Donut",
        "muffin": "Muffin",
        "pancake": "Pankek",
        "waffle": "Waffle",
        "ice cream": "Dondurma",
        "chocolate": "Çikolata",
        "candy": "Şeker",
        "pudding": "Puding",
        "tiramisu": "Tiramisu",
        "cheesecake": "Cheesecake",
        "french fries": "Patates kızartması",
        "fries": "Patates kızartması",
        "popcorn": "Patlamış mısır",
        "chips": "Cips",
        "pretzel": "Çubuk kraker",

        // İçecekler
        "water": "Su",
        "sparkling water": "Maden suyu",
        "coffee": "Kahve",
        "espresso": "Espresso",
        "latte": "Latte",
        "cappuccino": "Cappuccino",
        "tea": "Çay",
        "green tea": "Yeşil çay",
        "juice": "Meyve suyu",
        "orange juice": "Portakal suyu",
        "apple juice": "Elma suyu",
        "soda": "Gazlı içecek",
        "cola": "Kola",
        "lemonade": "Limonata",
        "wine": "Şarap",
        "beer": "Bira",
        "smoothie": "Smoothie",
        "milkshake": "Milkshake",
        "ayran": "Ayran",
        "raki": "Rakı",

        // Kuruyemiş & tohum
        "almond": "Badem",
        "almonds": "Badem",
        "walnut": "Ceviz",
        "walnuts": "Ceviz",
        "peanut": "Yer fıstığı",
        "peanuts": "Yer fıstığı",
        "hazelnut": "Fındık",
        "hazelnuts": "Fındık",
        "pistachio": "Antep fıstığı",
        "cashew": "Kaju",
        "sunflower seed": "Ay çekirdeği",
        "pumpkin seed": "Kabak çekirdeği",

        // Yumuşak/sosa benzer
        "ketchup": "Ketçap",
        "mayonnaise": "Mayonez",
        "mustard": "Hardal",
        "honey": "Bal",
        "jam": "Reçel",
        "peanut butter": "Fıstık ezmesi",
        "tahini": "Tahin",
        "molasses": "Pekmez"
    ]

    /// Verilen ham etiketi normalize edip sözlükte arar.
    /// - Tam eşleşme → değer
    /// - Compound etikette son anlamlı kelime ("granny smith apple" → "apple") → değer
    /// - Yoksa orijinal etiketin baş harfi büyük halini döner
    static func translate(_ rawLabel: String) -> String {
        let normalized = rawLabel
            .replacingOccurrences(of: "_", with: " ")
            .lowercased()
            .trimmingCharacters(in: .whitespaces)
        guard !normalized.isEmpty else { return rawLabel }

        if let exact = dictionary[normalized] {
            return exact
        }

        // ImageNet/Vision sınıfları genelde "granny smith apple" veya
        // "yellow_bell_pepper" gibi compound olabilir — son token'ı sözlükte ara.
        let tokens = normalized.split(separator: " ")
        if let last = tokens.last, let hit = dictionary[String(last)] {
            return hit
        }
        if tokens.count >= 2 {
            let lastTwo = tokens.suffix(2).joined(separator: " ")
            if let hit = dictionary[lastTwo] {
                return hit
            }
        }

        return normalized.prefix(1).uppercased() + normalized.dropFirst()
    }
}
