import Foundation
import Testing
@testable import Alfred

@Test func keychainSaveAndLoad() {
    let testKey = "test_key_\(UUID().uuidString)"
    KeychainStore.save(key: testKey, value: "test_value")
    let loaded = KeychainStore.load(key: testKey)
    #expect(loaded == "test_value")
    KeychainStore.delete(key: testKey)
}

@Test func keychainLoadReturnsNilForMissing() {
    let loaded = KeychainStore.load(key: "nonexistent_key_\(UUID().uuidString)")
    #expect(loaded == nil)
}

@Test func keychainDeleteRemovesValue() {
    let testKey = "test_delete_\(UUID().uuidString)"
    KeychainStore.save(key: testKey, value: "to_delete")
    KeychainStore.delete(key: testKey)
    let loaded = KeychainStore.load(key: testKey)
    #expect(loaded == nil)
}

@Test func keychainOverwritesExistingValue() {
    let testKey = "test_overwrite_\(UUID().uuidString)"
    KeychainStore.save(key: testKey, value: "original")
    KeychainStore.save(key: testKey, value: "updated")
    let loaded = KeychainStore.load(key: testKey)
    #expect(loaded == "updated")
    KeychainStore.delete(key: testKey)
}
