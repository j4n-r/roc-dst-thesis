//! Link-only probe host. Every hosted effect exits 86 rather than pretending to
//! implement simulation behavior. Only startup and ordinary allocation are real.
#![allow(unused_variables)]

mod roc_platform_abi;
use roc_platform_abi::*;
use std::ffi::{c_char, c_void, CStr};
use std::mem::ManuallyDrop;
use std::ptr::NonNull;

static mut HOST: *mut RocHost = std::ptr::null_mut();

#[no_mangle]
pub extern "C" fn roc_alloc(length: usize, alignment: usize) -> NonNull<c_void> {
    unsafe { DefaultAllocators::roc_alloc(HOST, length, alignment) }
}

#[no_mangle]
pub extern "C" fn roc_dealloc(ptr: *mut c_void, alignment: usize) {
    unsafe { DefaultAllocators::roc_dealloc(HOST, ptr, alignment) }
}

#[no_mangle]
pub extern "C" fn roc_realloc(
    ptr: *mut c_void,
    length: usize,
    alignment: usize,
) -> NonNull<c_void> {
    unsafe { DefaultAllocators::roc_realloc(HOST, ptr, length, alignment) }
}

#[no_mangle]
pub extern "C" fn roc_dbg(bytes: *const u8, len: usize) {
    unsafe { DefaultHandlers::roc_dbg(HOST, bytes, len) }
}

#[no_mangle]
pub extern "C" fn roc_expect_failed(bytes: *const u8, len: usize) {
    unsafe { DefaultHandlers::roc_expect_failed(HOST, bytes, len) }
    std::process::exit(87);
}

#[no_mangle]
pub extern "C" fn roc_crashed(bytes: *const u8, len: usize) {
    unsafe { DefaultHandlers::roc_crashed(HOST, bytes, len) }
    std::process::exit(88);
}

fn tripwire(symbol: &str) -> ! {
    eprintln!("LINK-ONLY HOST: {symbol}");
    std::process::exit(86);
}

include!("stubs.rs");

#[no_mangle]
pub extern "C" fn main(argc: i32, argv: *const *const c_char) -> i32 {
    let mut host = make_roc_host(std::ptr::null_mut());
    unsafe {
        HOST = &mut host;
        let args: RocList<OsStr> = RocList::allocate((argc - 1) as usize, &host);
        for index in 1..argc as usize {
            let bytes = CStr::from_ptr(*argv.add(index)).to_bytes();
            // Probe invocations use UTF-8 arguments; native non-Unicode argument
            // handling is deliberately outside this startup/linking experiment.
            std::str::from_utf8(bytes).unwrap();
            args.elements.add(index - 1).write(OsStr {
                payload: OsStrPayload {
                    utf8: ManuallyDrop::new(RocStr::from_slice(bytes, &host)),
                },
                tag: OsStrTag::Utf8,
            });
        }
        let code = roc_main(args);
        HOST = std::ptr::null_mut();
        code
    }
}
