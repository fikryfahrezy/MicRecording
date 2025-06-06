// Ref:
// https://gist.github.com/SteveTrewick/c0668ee438eb784cbc5fb4674f0c2cd1

import Foundation
import CoreAudio
import OSLog

/*
 
 So you want to get a list of audio input and output devices on macOS do you?
 Should be easy right?
 
 HAHAHAHAHAHAHAHAHAHAHAHAAAA no.
 
 If you just want input you can use an AVCaptureDevice.DiscoverySession
 
 But if you want output devices, you're gonna have to dip into Core Audio
 convince me I'm wrong, dear god, please convince me that is utterly unnecessary
 
 sigh, so here we go then
 */



public struct AudioDeviceEnumerator {
    
    
    /*
     seriously, that's all I wanted, just a list of devices with in/out
     and an identifier for them, just like this. This is where I started
     let's skate over for the moment that there are two seperate identifiers,
     depending on which set of APIs of the month we want to use them with
     that's really the least of it.
     */
    
    public struct Device {
        
        public let name         : String
        public let manufacturer : String
        public let uidString    : String
        public let deviceID     : AudioDeviceID
        
        public let output       : UInt32  // number of channels
        public let input        : UInt32
    }
    
    
    
    /*
     Here we start to see the head of the apalling eldritch horror we're going to encounter
     to complete this simple task.
     
     Since we're dipping down to aincent C APIs, we have a load of kArgleBlargeGuffle consts
     and I am NOT typing that shit every time I want to make an API call, fuck that noise,
     so here I'm wrapping them up for autocompletion and call site hygeine purposes
     
     each API call requires an ID and an address, actually a AudioObjectPropertyAddress
     which we'll construct later, which conists of a selector, a scope and an element.
     */
    
    
    private enum Selector {
        
        /*
         what do we want? (and why do all consts start with k, konstant, AHAHAHAHAHAHAHHA, I GET IT)
         */
        
        case devices, name, manufacturer, uniqID, streamConfig
        
        var value : AudioObjectPropertySelector {
            
            switch self {
            case .devices      : return kAudioHardwarePropertyDevices
            case .name         : return kAudioDevicePropertyDeviceNameCFString
            case .manufacturer : return kAudioDevicePropertyDeviceManufacturerCFString
            case .uniqID       : return kAudioDevicePropertyDeviceUID
            case .streamConfig : return kAudioDevicePropertyStreamConfiguration
            }
        }
    }
    
    
    
    private enum Scope {
        
        /*
         where is it?
         */
        
        case global, input, output
        
        var value : AudioObjectPropertyScope {
            
            switch self {
            case .global : return kAudioObjectPropertyScopeGlobal
            case .input  : return kAudioDevicePropertyScopeInput
            case .output : return kAudioDevicePropertyScopeOutput
            }
        }
    }
    
    
    /*
     a container for all that nonsense. look how much code there is already and we haven't
     even called an API yet!
     */
    
    private struct Address {
        
        let selector : Selector
        let scope    : Scope
        let element  : AudioObjectPropertyElement
        
        /*
         NB that the AudioObjectPropertyElement doesn't ever seem to need to be set to
         anything other than 0, but since there's no actual documentation, who knows?
         seriously, go look at : https://developer.apple.com/documentation/coreaudio/audioobjectpropertyelement
         Not that the others are any better. Oh and don't be fooled by the types, they're all
         just aliases to Ints, but which ints? Do we trust that not to change? we do not!
         */
        
        init(selector: Selector, scope: Scope, element: AudioObjectPropertyElement = 0) {
            self.selector = selector
            self.scope    = scope
            self.element  = element
        }
        
        /*
         construct the kageleblagles
         */
        var apivalue : AudioObjectPropertyAddress {
            AudioObjectPropertyAddress (
                mSelector: selector.value,
                mScope   : scope.value,
                mElement : element
            )
        }
    }
    
    
    /*
     I'm just going to throw debug log messages for any bad results, because
     they'll be param errors and also utterly inscrutable to any poor end user
     and indeed, largely to me. Technically, that means that *this code* is in error
     and some people would say you should therefore use assert() agressivley, but that's
     actually really unfriendly if someone else wants to use your code,
     isn't it Julian, you prick?
     */
    private let log = Logger(subsystem: "AudioDeviceEnumerator", category: "error")
    
    
    
    
    /*
     Right here we go. We're to use AudioObjectGetPropertyData which is a C API
     of the popular form :
     
     error = do_some_things([shitload of params])
     
     where one of the shitload of params is an untyped pointer, and some of them are
     optional in some cases but which ones aren't documented
     
     sigh
     
     It follows then that are essentially two broad classes of thigs that these
     untyped pointers can be pointing to, scalar values and arrays (pointers to
     arrays, actually, as it happens, but lets' pretend thats not a thing in 2022,
     which works right up until it doesn't)
     
     since there are only two foundational calls then, let's wrap them and keep all the
     kblargles and all the nasty pointer shit contained in there as much as possible.
     
     */
    
    
    
    
    private func propertyScalar<T>(id: AudioObjectID, address: Address, type: T.Type) -> T? {
        
        /*
         OK, so a scalar value, one of something, but what? Who the fuck knows?
         Maybe if you search the headers and old mailing list posts you can find out?
         Once you do, figure out how that maps into swift and do this.
         
         Allocate some storage for your thing, figure out how big that storage is and
         filing them at the API. And yes, you need the size or this fails
         
         The return value is optional because there is not a reliable generic
         way to provide a default value for all the things we might ask for, and because
         if we make an oopsy, our property won't get filled anyway
         */
        
        var property : T? = nil
        var size     = UInt32(MemoryLayout<T>.size)
        var apivalue  = address.apivalue
        
        let osresult = AudioObjectGetPropertyData(id, &apivalue, 0, nil, &size, &property)
        
        if osresult != 0 { log.error("AudioObjectGetPropertyData error: \(osresult)") }
        
        return property
    }
    
    
    
    
    /*
     Arrays of things (actually pointers to things), we'll need to know how big these are,
     so we have to ask first. Yes, I know, you'd think so. But no *you* have to it.
     
     NB that this returns the number of bytes required for *all the things* not number of things
     */
    
    private func propertyDataSize(id: AudioObjectID, address: Address) -> UInt32 {
        
        var bytes    : UInt32 = 0
        var apivalue = address.apivalue
        let osresult = AudioObjectGetPropertyDataSize(id, &apivalue, 0, nil, &bytes)
        
        if osresult != 0 { log.error("AudioObjectGetPropertyDataSize error: \(osresult)") }
        
        return bytes
    }
    
    /*
     Now we know how big our list of things is, we can allocate some storage and retrieve them.
     I say 'them', frequently in fact just 'it' but you have tyo get it like this because reasons.
     See how Swift reminds us that this is unsafe by naming all it's methods for doing this kind
     of shit Unsafe? Yeah.
     */
    
    private func propertyArray<T>(id: AudioObjectID, address: Address, bytes: UInt32, type: T.Type) -> [T] {
        
        var size     = bytes
        var apivalue  = address.apivalue
        
        /*
         remember, we only know how many bytes we have to compute from
         that the number of actual things
         */
        let count    = Int(bytes) / MemoryLayout<T>.size
        
        let buffptr  = UnsafeMutablePointer<T>.allocate(capacity: count)
        let osresult = AudioObjectGetPropertyData(id, &apivalue, 0, nil, &size, buffptr)
        
        if osresult != 0 { log.error("AudioObjectGetPropertyData error: \(osresult)") }
        
        /*
         For an array of things [T], there is in fact a sensible default value, [],
         the empty list, so if we get 0 here we just return an empty list,
         if this isn't matching your expectations, check your logs for inscruatble
         error codes.
         */
        return Array(UnsafeBufferPointer(start: buffptr, count: count))
        
        
    }
    
    
    
    /*
     Many of the things we want are atrings, well, actually they are CFStrings,
     but anyhoo, they are in the global scope and a sensible default for a atring
     is the empty string and I'm not typing this however many times it turns out to be
     as this no doubt expands into some monsterous CA wrapper.
     */
    private func globalDeviceString(id: AudioDeviceID, selector: Selector) -> String {
        propertyScalar (
            id     : id,
            address: .init(selector: selector, scope: .global),
            type   : CFString.self
        )
        as String? ?? ""
    }
    
    
    
    /*
     I want to know if a device is capable of input or output, for this, we have to retrieve
     an AudioBufferList struct. Yes, just one, yes it has to be called this way, no, I don't
     know why. None of the devices on my machine have more than one, nor do the various USB
     things that plug into it, so I dunno, YMMV here.
     
     We pull a bufferlist for the relevant scope and (sort of) count channels,
     I actually was doing this with just a bool, but the info is there, so why throw it away?
     
     Again technically, mBuffers is a pointer, the first of a possible array,
     I haven't encountered a device that has more than one of these, even
     the 16 channel Existential Audio virtual device I'm using has only the one
     
     If this turns out to be an issue, turn mBuffers into an array of AudioBuffer
     and go nuts.
     */
    private func deviceIOBuffer(id: AudioDeviceID, scope: Scope) -> UInt32 {
        
        let address = Address(selector: .streamConfig, scope: scope)
        
        let size        = propertyDataSize(id: id, address: address)
        let buffpointer = propertyArray(id: id, address: address, bytes: size, type: AudioBufferList.self)
        
        for bufferlist in buffpointer {
            return bufferlist.mBuffers.mNumberChannels
        }
        
        return 0
    }
    
    
    /*
     Oh yeah, to get info on a device, we must first get a list of the devices
     Core Audio IDs
     
     */
    private func queryAudioDeviceIDs() -> [AudioDeviceID] {
        
        let address = Address(selector: .devices, scope: .global)
        let id      = AudioObjectID(kAudioObjectSystemObject)
        let size    = propertyDataSize(id: id, address: address)
        
        return propertyArray(id: id, address: address, bytes: size, type: AudioDeviceID.self)
        
    }
    
    
    /*
     And now *FINALLY* we can actually get a list of devices, capabilities, names, manufacturers
     and the two IDs tha we need for the various APIs
     
     Sheesh
     */
    
    public func listDevices() -> [Device] {
        
        var devices : [Device] = []
        
        let result  = queryAudioDeviceIDs()
        
        
        for deviceID in result {
            
            let name   = globalDeviceString(id: deviceID, selector: .name)
            let manf   = globalDeviceString(id: deviceID, selector: .manufacturer)
            let uniq   = globalDeviceString(id: deviceID, selector: .uniqID)
            let input  = deviceIOBuffer(id: deviceID, scope: .input)
            let output = deviceIOBuffer(id: deviceID, scope: .output)
            
            devices += [
                Device (
                    name        : name,
                    manufacturer: manf,
                    uidString   : uniq,
                    deviceID    : deviceID,
                    output      : output,
                    input       : input
                )
            ]
            
        }
        
        return devices
    }
    
}


