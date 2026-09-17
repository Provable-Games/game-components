#[starknet::contract]
pub mod ERC2981Mock {
    // Explicit expansion of the pinned upstream with_components macro.
    use crate::common::erc2981::ERC2981Component;
    component!(path: ERC2981Component, storage: erc2981, event: ERC2981Event);
    impl ERC2981InternalImpl = ERC2981Component::InternalImpl<ContractState>;
    use openzeppelin_introspection::src5::SRC5Component;
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    impl SRC5InternalImpl = SRC5Component::InternalImpl<ContractState>;
    use starknet::ContractAddress;
    use crate::common::erc2981::DefaultConfig;

    #[abi(embed_v0)]
    impl ERC2981Impl = ERC2981Component::ERC2981Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC2981InfoImpl = ERC2981Component::ERC2981InfoImpl<ContractState>;

    // SRC5
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        pub erc2981: ERC2981Component::Storage,
        #[substorage(v0)]
        pub src5: SRC5Component::Storage,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        default_receiver: ContractAddress,
        default_royalty_fraction: u128,
    ) {
        self.erc2981.initializer(default_receiver, default_royalty_fraction);
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC2981Event: ERC2981Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }
}

#[starknet::contract]
pub mod ERC2981OwnableMock {
    // Explicit expansion of the pinned upstream with_components macro.
    use crate::common::erc2981::ERC2981Component;
    component!(path: ERC2981Component, storage: erc2981, event: ERC2981Event);
    impl ERC2981InternalImpl = ERC2981Component::InternalImpl<ContractState>;
    use openzeppelin_introspection::src5::SRC5Component;
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    impl SRC5InternalImpl = SRC5Component::InternalImpl<ContractState>;
    use openzeppelin_access::ownable::OwnableComponent;
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    use starknet::ContractAddress;
    use crate::common::erc2981::DefaultConfig;

    // ERC2981
    #[abi(embed_v0)]
    impl ERC2981Impl = ERC2981Component::ERC2981Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC2981InfoImpl = ERC2981Component::ERC2981InfoImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC2981AdminOwnableImpl =
        ERC2981Component::ERC2981AdminOwnableImpl<ContractState>;

    // Ownable
    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;

    // SRC5
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        pub erc2981: ERC2981Component::Storage,
        #[substorage(v0)]
        pub src5: SRC5Component::Storage,
        #[substorage(v0)]
        pub ownable: OwnableComponent::Storage,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        default_receiver: ContractAddress,
        default_royalty_fraction: u128,
    ) {
        self.erc2981.initializer(default_receiver, default_royalty_fraction);
        self.ownable.initializer(owner);
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC2981Event: ERC2981Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }
}

#[starknet::contract]
pub mod ERC2981AccessControlMock {
    // Explicit expansion of the pinned upstream with_components macro.
    use crate::common::erc2981::ERC2981Component;
    component!(path: ERC2981Component, storage: erc2981, event: ERC2981Event);
    impl ERC2981InternalImpl = ERC2981Component::InternalImpl<ContractState>;
    use openzeppelin_introspection::src5::SRC5Component;
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    impl SRC5InternalImpl = SRC5Component::InternalImpl<ContractState>;
    use openzeppelin_access::accesscontrol::AccessControlComponent;
    component!(path: AccessControlComponent, storage: access_control, event: AccessControlEvent);
    impl AccessControlInternalImpl = AccessControlComponent::InternalImpl<ContractState>;
    use openzeppelin_access::accesscontrol::DEFAULT_ADMIN_ROLE;
    use starknet::ContractAddress;
    use crate::common::erc2981::DefaultConfig;
    use crate::common::erc2981::ERC2981Component::ROYALTY_ADMIN_ROLE;

    // ERC2981
    #[abi(embed_v0)]
    impl ERC2981Impl = ERC2981Component::ERC2981Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC2981InfoImpl = ERC2981Component::ERC2981InfoImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC2981AdminAccessControlImpl =
        ERC2981Component::ERC2981AdminAccessControlImpl<ContractState>;

    // AccessControl
    #[abi(embed_v0)]
    impl AccessControlImpl =
        AccessControlComponent::AccessControlImpl<ContractState>;

    // SRC5
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        pub erc2981: ERC2981Component::Storage,
        #[substorage(v0)]
        pub src5: SRC5Component::Storage,
        #[substorage(v0)]
        pub access_control: AccessControlComponent::Storage,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        default_receiver: ContractAddress,
        default_royalty_fraction: u128,
    ) {
        self.erc2981.initializer(default_receiver, default_royalty_fraction);
        self.access_control.initializer();
        self.access_control._grant_role(DEFAULT_ADMIN_ROLE, owner);
        self.access_control._grant_role(ROYALTY_ADMIN_ROLE, owner);
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC2981Event: ERC2981Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
    }
}

#[starknet::contract]
pub mod ERC2981AccessControlDefaultAdminRulesMock {
    // Explicit expansion of the pinned upstream with_components macro.
    use crate::common::erc2981::ERC2981Component;
    component!(path: ERC2981Component, storage: erc2981, event: ERC2981Event);
    impl ERC2981InternalImpl = ERC2981Component::InternalImpl<ContractState>;
    use openzeppelin_introspection::src5::SRC5Component;
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    impl SRC5InternalImpl = SRC5Component::InternalImpl<ContractState>;
    use openzeppelin_access::accesscontrol::extensions::AccessControlDefaultAdminRulesComponent;
    component!(
        path: AccessControlDefaultAdminRulesComponent,
        storage: access_control_dar,
        event: AccessControlDefaultAdminRulesEvent,
    );
    impl AccessControlDefaultAdminRulesInternalImpl =
        AccessControlDefaultAdminRulesComponent::InternalImpl<ContractState>;
    use openzeppelin_access::accesscontrol::extensions::DefaultConfig as AccessControlDefaultAdminRulesDefaultConfig;
    use starknet::ContractAddress;
    use crate::common::erc2981::DefaultConfig as ERC2981DefaultConfig;
    use crate::common::erc2981::ERC2981Component::ROYALTY_ADMIN_ROLE;

    // ERC2981
    #[abi(embed_v0)]
    impl ERC2981Impl = ERC2981Component::ERC2981Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC2981InfoImpl = ERC2981Component::ERC2981InfoImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC2981AdminAccessControlDefaultAdminRulesImpl =
        ERC2981Component::ERC2981AdminAccessControlDefaultAdminRulesImpl<ContractState>;

    // AccessControl
    #[abi(embed_v0)]
    impl AccessControlImpl =
        AccessControlDefaultAdminRulesComponent::AccessControlImpl<ContractState>;

    // SRC5
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    pub const INITIAL_DELAY: u64 = 3600; // 1 hour

    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        pub erc2981: ERC2981Component::Storage,
        #[substorage(v0)]
        pub src5: SRC5Component::Storage,
        #[substorage(v0)]
        pub access_control_dar: AccessControlDefaultAdminRulesComponent::Storage,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        default_receiver: ContractAddress,
        default_royalty_fraction: u128,
    ) {
        self.erc2981.initializer(default_receiver, default_royalty_fraction);
        self.access_control_dar.initializer(INITIAL_DELAY, owner);
        self.access_control_dar._grant_role(ROYALTY_ADMIN_ROLE, owner);
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC2981Event: ERC2981Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        AccessControlDefaultAdminRulesEvent: AccessControlDefaultAdminRulesComponent::Event,
    }
}
