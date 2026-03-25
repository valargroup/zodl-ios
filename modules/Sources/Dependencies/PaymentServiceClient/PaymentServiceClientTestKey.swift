import ComposableArchitecture

extension PaymentServiceClient: TestDependencyKey {
    public static let testValue = Self()
}
