/**

## The Flow Non-Fungible Token standard

## `NonFungibleToken` contract interface

The interface that all Non-Fungible Token contracts should conform to.
If a user wants to deploy a new NFT contract, their contract would need
to implement the NonFungibleToken interface.

Their contract must follow all the rules and naming
that the interface specifies.

## `NFT` resource

The core resource type that represents an NFT in the smart contract.

## `Collection` Resource

The resource that stores a user's NFT collection.
It includes a few functions to allow the owner to easily
move tokens in and out of the collection.

## `Provider` and `Receiver` resource interfaces

These interfaces declare functions with some pre and post conditions
that require the Collection to follow certain naming and behavior standards.

They are separate because it gives the user the ability to share a reference
to their Collection that only exposes the fields and functions in one or more
of the interfaces. It also gives users the ability to make custom resources
that implement these interfaces to do various things with the tokens.

By using resources and interfaces, users of NFT smart contracts can send
and receive tokens peer-to-peer, without having to interact with a central ledger
smart contract.

To send an NFT to another user, a user would simply withdraw the NFT
from their Collection, then call the deposit function on another user's
Collection to complete the transfer.

*/

import MetadataViews from "./MetadataViews.cdc"

/// The main NFT contract interface. Other NFT contracts will
/// import and implement this interface
///
pub contract interface NonFungibleToken {

    /// Event that is emitted when a token is withdrawn,
    /// indicating the owner of the collection that it was withdrawn from.
    ///
    /// If the collection is not in an account's storage, `from` will be `nil`.
    ///
    pub event Withdraw(id: UInt64, uuid: UInt64, from: Address?, type: String, 
                       name: String, thumbnailURI: String?)

    /// Event that emitted when a token is deposited to a collection.
    ///
    /// It indicates the owner of the collection that it was deposited to.
    ///
    pub event Deposit(id: UInt64, uuid: UInt64, to: Address?, type: String,
                      name: String, thumbnailURI: String?)

    /// Transfer
    ///
    /// The event that should be emitted when tokens are transferred from one account to another
    ///
    pub event Transfer(id: UInt64, uuid: UInt64, from: Address?, to: Address?, type: String,
                      name: String, thumbnailURI: String?)

    /// Mint
    ///
    /// The event that should be emitted when an NFT is minted
    pub event Mint(id: UInt64, uuid: UInt64, type: String,
                   name: String, thumbnailURI: String?)

    /// Destroy
    ///
    /// The event that should be emitted when an NFT is destroyed
    pub event Destroy(id: UInt64, uuid: UInt64, type: String,
                      name: String, thumbnailURI: String?)

    /// Interface that the NFTs must conform to
    ///
    pub resource interface NFT { //: MetadataViews.Resolver {
        /// The unique ID that each NFT has
        pub fun getID(): UInt64 {
            return self.uuid
        }

        pub fun getViews(): [Type] {
            return []
        }
        pub fun resolveView(_ view: Type): AnyStruct? {
            return nil
        }
    }

    /// Interface to mediate withdraws from the Collection
    ///
    pub resource interface Provider {
        /// Function for projects to indicate if they are using UUID or not
        pub fun usesUUID(): Bool {
            return false
        }

        /// withdraw removes an NFT from the collection and moves it to the caller
        /// It does not specify whether the ID is UUID or not
        pub fun withdraw(withdrawID: UInt64): @AnyResource{NFT} {
            post {
                result.getID() == withdrawID: "The ID of the withdrawn token must be the same as the requested ID"
            }
        }

        /// Alternate withdraw methods
        /// The next three withdraw methods allow projects to have more flexibility
        /// to indicate how their NFTs are meant to be used
        /// With the v2 upgrade, some projects will be using UUID and others
        /// will be using custom IDs, so projects can pick and choose which
        /// of these withdraw methods applies to them

        /// withdrawWithUUID removes an NFT from the collection, using its UUID, and moves it to the caller
        pub fun withdrawWithUUID(_ uuid: UInt64): @AnyResource{NFT} {
            post {
                result == nil || result!.uuid == uuid: "The ID of the withdrawn token must be the same as the requested ID"
            }
        }

        /// withdrawWithType removes an NFT from the collection, using its Type and ID and moves it to the caller
        /// This would be used by a collection that can store multiple NFT types
        pub fun withdrawWithType(type: Type, withdrawID: UInt64): @AnyResource{NFT} {
            post {
                result == nil || result.getID() == withdrawID: "The ID of the withdrawn token must be the same as the requested ID"
            }
        }

        /// withdrawWithTypeAndUUID removes an NFT from the collection using its type and uuid and moves it to the caller
        /// This would be used by a collection that can store multiple NFT types
        pub fun withdrawWithTypeAndUUID(type: Type, uuid: UInt64): @AnyResource{NFT} {
            post {
                result == nil || result!.uuid == uuid: "The ID of the withdrawn token must be the same as the requested ID"
            }
        }
    }

    /// Interface to mediate withdrawals from the Collection
    ///
    pub resource interface Transferor {
        /// withdraw removes an NFT from the collection and moves it to the caller
        pub fun transfer(id: UInt64, receiver: Capability<&AnyResource{Receiver}>): Bool
    }

    /// Interface to mediate deposits to the Collection
    ///
    pub resource interface Receiver {

        /// deposit takes an NFT as an argument and adds it to the Collection
        ///
        pub fun deposit(token: @AnyResource{NFT})

        /// getSupportedNFTTypes returns a list of NFT types that this receiver accepts
        pub fun getSupportedNFTTypes(): {Type: Bool} {
            return {}
        }

        /// Returns whether or not the given type is accepted by the collection
        /// A collection that can accept any type should just return true by default
        pub fun isSupportedNFTType(type: Type): Bool {
            return false
        }
    }

    /// Interface that an account would commonly 
    /// publish for their collection
    pub resource interface CollectionPublic { //: MetadataViews.ResolverCollection {
        pub fun deposit(token: @AnyResource{NFT})
        pub fun usesUUID(): Bool
        pub fun getSupportedNFTTypes(): {Type: Bool}
        pub fun isSupportedNFTType(type: Type): Bool
        pub fun borrowViewResolver(id: UInt64): &{MetadataViews.Resolver}?
        pub fun getDefaultStoragePath(): StoragePath?
        pub fun getDefaultPublicPath(): PublicPath?
        pub fun getIDs(): [UInt64]
        pub fun getIDsWithTypes(): {Type: [UInt64]} {
            return {}
        }
        pub fun borrowNFT(_ id: UInt64): &AnyResource{NFT}
        /// Safe way to borrow a reference to an NFT that does not panic
        ///
        /// @param id: The ID of the NFT that want to be borrowed
        /// @return An optional reference to the desired NFT, will be nil if the passed id does not exist
        ///
        pub fun borrowNFTSafe(id: UInt64): &{NFT}? {
            post {
                (result == nil) || (result?.getID() == id): 
                    "Cannot borrow NFT reference: The ID of the returned reference does not match the ID that was specified"
            }
            return nil
        }
    }

    /// Requirement for the concrete resource type
    /// to be declared in the implementing contract
    ///
    pub resource interface Collection { //: Provider, Receiver, Transferor, CollectionPublic, MetadataViews.ResolverCollection {

        /// Return the default storage path for the collection
        pub fun getDefaultStoragePath(): StoragePath? {
            return nil
        }

        /// Return the default public path for the collection
        pub fun getDefaultPublicPath(): PublicPath? {
            return nil
        }

        /// Normally we would require that the collection specify
        /// a specific dictionary to store the NFTs, but this isn't necessary any more
        /// as long as all the other functions are there

        /// Returns the NFT types that this collection can store
        /// If the collection can accept any NFT type, it should return
        /// a one element dictionary with the key type as `@AnyResource{NonFungibleToken.NFT}`
        pub fun getSupportedNFTTypes(): {Type: Bool}

        /// Returns whether or not the given type is accepted by the collection
        pub fun isSupportedNFTType(type: Type): Bool

        /// createEmptyCollection creates an empty Collection
        /// and returns it to the caller so that they can own NFTs
        pub fun createEmptyCollection(): @{Collection} {
            post {
                result.getIDs().length == 0: "The created collection must be empty!"
            }
        }

        pub fun usesUUID(): Bool {
            return false
        }

        /// withdraw removes an NFT from the collection and moves it to the caller
        pub fun withdraw(withdrawID: UInt64): @AnyResource{NonFungibleToken.NFT}

        /// deposit takes a NFT and adds it to the collections dictionary
        /// and adds the ID to the id array
        pub fun deposit(token: @AnyResource{NonFungibleToken.NFT})

        /// Function for a direct transfer instead of having to do a deposit and withdrawal
        ///
        pub fun transfer(id: UInt64, receiver: Capability<&AnyResource{NonFungibleToken.Receiver}>): Bool

        /// getIDs returns an array of the IDs that are in the collection
        pub fun getIDs(): [UInt64]

        /// getIDsWithTypes returns a list of IDs that are in the collection, keyed by type
        /// Should only be used by collections that can store multiple NFT types
        pub fun getIDsWithTypes(): {Type: [UInt64]}

        /// Returns a borrowed reference to an NFT in the collection
        /// so that the caller can read data and call methods from it
        pub fun borrowNFT(_ id: UInt64): &AnyResource{NonFungibleToken.NFT}

        /// From the MetadataViews Contract
        /// borrows a reference to get metadata views for the NFTs that the contract contains
        pub fun borrowViewResolver(id: UInt64): &{MetadataViews.Resolver}?

        pub fun borrowNFTSafe(id: UInt64): &{NonFungibleToken.NFT}? {
            post {
                (result == nil) || (result?.getID() == id): 
                    "Cannot borrow NFT reference: The ID of the returned reference does not match the ID that was specified"
            }
            return nil
        }
    }

    /// Return the types that the contract defines
    pub fun getNFTTypes(): [Type] {
        post {
            result.length > 0: "Must indicate what non-fungible token types this contract defines"
        }
    }

    /// get a list of all the NFT collection types that the contract defines
    /// could include a post-condition that verifies that each Type is an NFT collection type
    pub fun getCollectionTypes(): [Type]

    /// tells what collection type should be used for the specified NFT type
    /// return `nil` if no collection type exists for the specified NFT type
    pub fun getCollectionTypeForNftType(nftType: Type): Type?

    pub fun getViews(): [Type] {
        return []
    }

    pub fun resolveView(_ view: Type): AnyStruct? {
        return nil
    }

    /// createEmptyCollection creates an empty Collection
    /// and returns it to the caller so that they can own NFTs
    pub fun createEmptyCollection(collectionType: Type): @{Collection} {
        post {
            result.getIDs().length == 0: "The created collection must be empty!"
            result.getType() == collectionType: "The created collection is of the wrong type"
        }
    }
}
