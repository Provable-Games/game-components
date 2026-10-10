use game_components_interfaces::entry_requirement::{
    IEntryRequirementDispatcher, IEntryRequirementDispatcherTrait,
};
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
use starknet::ContractAddress;
use crate::entry_requirement::structs::{
    EntryRequirement, EntryRequirementType, NFTQualification, QualificationProof,
};

#[starknet::interface]
trait IHostRequirement<T> {
    fn configure(ref self: T, id: u64, requirement: Option<EntryRequirement>);
    fn enter(
        ref self: T, id: u64, proof: QualificationProof, qualifier: Option<ContractAddress>,
    ) -> ContractAddress;
}
#[starknet::interface]
trait INftSetup<T> {
    fn set_owner(ref self: T, token_id: u256, owner: ContractAddress);
}

#[starknet::contract]
mod HostRequirement {
    use starknet::ContractAddress;
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    use crate::entry_requirement::api::{
        EntryRequirementInternalImpl, EntryRequirementInternalTrait,
    };
    use crate::entry_requirement::entry_requirement_store::{
        EntryRequirementStoreImpl, EntryRequirementStoreTrait,
    };
    use crate::entry_requirement::store::Store;
    use crate::entry_requirement::structs::{
        EntryRequirement, EntryRequirementMeta, QualificationProof,
    };
    #[storage]
    struct Storage {
        custom_config: Map<u64, u64>,
        nft: Map<u64, ContractAddress>,
        validator: Map<u64, ContractAddress>,
        uses: Map<(u64, felt252), u32>,
    }
    #[abi(embed_v0)]
    impl Views = crate::entry_requirement::api::EntryRequirementImpl<ContractState>;
    impl HostStore of Store<ContractState> {
        fn get_meta(self: @ContractState, context_id: u64) -> EntryRequirementMeta {
            let packed = self.custom_config.read(context_id);
            EntryRequirementMeta {
                entry_limit: (packed / 0x100).try_into().unwrap(),
                req_type: (packed & 0xff).try_into().unwrap(),
            }
        }
        fn set_meta(ref self: ContractState, context_id: u64, meta: EntryRequirementMeta) {
            self
                .custom_config
                .write(
                    context_id,
                    Into::<u32, u64>::into(meta.entry_limit) * 0x100 + meta.req_type.into(),
                );
        }
        fn get_token(self: @ContractState, context_id: u64) -> ContractAddress {
            self.nft.read(context_id)
        }
        fn set_token(ref self: ContractState, context_id: u64, token: ContractAddress) {
            self.nft.write(context_id, token);
        }
        fn get_extension_address(self: @ContractState, context_id: u64) -> ContractAddress {
            self.validator.read(context_id)
        }
        fn set_extension_address(
            ref self: ContractState, context_id: u64, address: ContractAddress,
        ) {
            self.validator.write(context_id, address);
        }
        fn get_qualification_entries(self: @ContractState, context_id: u64, hash: felt252) -> u32 {
            self.uses.read((context_id, hash))
        }
        fn set_qualification_entries(
            ref self: ContractState, context_id: u64, hash: felt252, count: u32,
        ) {
            self.uses.write((context_id, hash), count);
        }
    }
    #[abi(embed_v0)]
    impl TestApi of super::IHostRequirement<ContractState> {
        fn configure(ref self: ContractState, id: u64, requirement: Option<EntryRequirement>) {
            EntryRequirementInternalTrait::set_entry_requirement(ref self, id, requirement);
        }
        fn enter(
            ref self: ContractState,
            id: u64,
            proof: QualificationProof,
            qualifier: Option<ContractAddress>,
        ) -> ContractAddress {
            let req = EntryRequirementStoreTrait::get_entry_requirement(@self, id).unwrap();
            let player = EntryRequirementStoreTrait::validate_qualification(
                @self, id, req, proof, qualifier,
            );
            EntryRequirementStoreTrait::update_qualification_entries(ref self, id, proof, req);
            player
        }
    }
}
fn deploy() -> (IHostRequirementDispatcher, IEntryRequirementDispatcher, ContractAddress) {
    let cls = declare("HostRequirement").unwrap().contract_class();
    let (address, _) = cls.deploy(@array![]).unwrap();
    let nft_cls = declare("ERC721Mock").unwrap().contract_class();
    let (nft, _) = nft_cls.deploy(@array![]).unwrap();
    (
        IHostRequirementDispatcher { contract_address: address },
        IEntryRequirementDispatcher { contract_address: address },
        nft,
    )
}
#[test]
fn entry_requirement_host_storage_validates_and_tracks_contexts() {
    let (host, views, nft) = deploy();
    let player: ContractAddress = 0x123.try_into().unwrap();
    let proof = QualificationProof::NFT(NFTQualification { token_id: 1 });
    INftSetupDispatcher { contract_address: nft }.set_owner(1, player);
    assert!(views.get_entry_requirement(1).is_none());
    let req = EntryRequirement {
        entry_limit: 2, entry_requirement_type: EntryRequirementType::token(nft),
    };
    host.configure(1, Option::Some(req));
    assert!(views.get_entry_requirement(1).unwrap() == req);
    assert!(host.enter(1, proof, Option::Some(player)) == player);
    assert!(host.enter(1, proof, Option::None) == player);
    assert!(views.get_qualification_entries(1, proof).entry_count == 2);
    assert!(views.get_qualification_entries(2, proof).entry_count == 0);
    host.configure(2, Option::Some(req));
    assert!(host.enter(2, proof, Option::None) == player);
    host.configure(1, Option::None);
    assert!(views.get_entry_requirement(1).is_none());
    assert!(
        views.get_qualification_entries(1, proof).entry_count == 2,
        "configuration does not erase qualification history",
    );
}
#[test]
#[should_panic(expected: "EntryRequirement: Maximum qualified entries reached for context 1")]
fn entry_requirement_host_storage_enforces_limit() {
    let (host, _, nft) = deploy();
    let player: ContractAddress = 0x123.try_into().unwrap();
    INftSetupDispatcher { contract_address: nft }.set_owner(1, player);
    host
        .configure(
            1,
            Option::Some(
                EntryRequirement {
                    entry_limit: 1, entry_requirement_type: EntryRequirementType::token(nft),
                },
            ),
        );
    let proof = QualificationProof::NFT(NFTQualification { token_id: 1 });
    host.enter(1, proof, Option::None);
    host.enter(1, proof, Option::None);
}
#[test]
#[should_panic(expected: "EntryRequirement: claimed qualifier does not own the gating NFT")]
fn entry_requirement_host_storage_rejects_wrong_owner() {
    let (host, _, nft) = deploy();
    let player: ContractAddress = 0x123.try_into().unwrap();
    INftSetupDispatcher { contract_address: nft }.set_owner(1, player);
    host
        .configure(
            1,
            Option::Some(
                EntryRequirement {
                    entry_limit: 1, entry_requirement_type: EntryRequirementType::token(nft),
                },
            ),
        );
    host
        .enter(
            1,
            QualificationProof::NFT(NFTQualification { token_id: 1 }),
            Option::Some(0x456.try_into().unwrap()),
        );
}
