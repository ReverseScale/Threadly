//
//  ThreadlyTests.swift
//  ThreadlyTests
//
//  The MIT License (MIT)
//
//  Copyright (c) 2017 Nikolai Vazquez
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import XCTest
import Foundation
import Threadly

func withDetachedThread(_ block: @escaping () -> ()) {
    #if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
        class ThreadHandler {
            var block: () -> ()

            init(block: @escaping () -> ()) { self.block = block }

            @objc func perform() { block() }
        }
        let handler = ThreadHandler(block: block)
        Thread.detachNewThreadSelector(#selector(ThreadHandler.perform), toTarget: handler, with: nil)
    #else
        Thread.detachNewThread(block)
    #endif
}

class ThreadlyTests: XCTestCase {

    static let allTests = [
        ("testDeallocation", testDeallocation),
        ("testExclusivity", testExclusivity)
    ]

    func testDeallocation() {
        class DeinitFulfiller {
            var expectation: XCTestExpectation

            init(expectation: XCTestExpectation) { self.expectation = expectation }

            deinit { expectation.fulfill() }
        }

        func helper(count: UInt) {
            let expct = expectation(description: "deinit")
            let dummy = ThreadLocal(create: { DeinitFulfiller(expectation: expct) })

            withDetachedThread {
                for _ in 0 ..< count {
                    let _ = dummy.inner.value
                }
            }
            
            waitForExpectations(timeout: 1, handler: nil)
        }

        // Test single access
        helper(count: 1)

        // Test multiple accesses
        helper(count: 10)
    }

    func testExclusivity() {
        let expect = expectation(description: "inequality")
        let number = ThreadLocal(value: 42)

        let mainAddress = UnsafeMutablePointer(&number.inner.value)

        withDetachedThread {
            let otherAddress = UnsafeMutablePointer(&number.inner.value)
            if otherAddress != mainAddress {
                expect.fulfill()
            }
        }

        waitForExpectations(timeout: 1, handler: nil)
    }

}
