struct MarginResponse: Decodable {
    struct Legs: Decodable {
        let shortPe: Int
        let longPe:  Int
        let shortCe: Int
        let longCe:  Int
    }
    let marginRequired: Int
    let perLot:         Int
    let method:         String
    let spot:           Double
    let atm:            Int
    let legs:           Legs
    let lotSize:        Int
    let lots:           Int
    let qty:            Int
}
