// SPDX-License-Identifier: MIT
// This contract is based off RedirectAll.sol 
pragma solidity 0.8.13;

import {ISuperfluid, ISuperToken, ISuperApp, ISuperAgreement, SuperAppDefinitions} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol"; //"@superfluid-finance/ethereum-monorepo/packages/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

import {CFAv1Library} from "@superfluid-finance/ethereum-contracts/contracts/apps/CFAv1Library.sol";

import {IConstantFlowAgreementV1} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";

import {SuperAppBase} from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperAppBase.sol";

contract RentRouter is SuperAppBase {

    using CFAv1Library for CFAv1Library.InitData;

    CFAv1Library.InitData public cfaV1Lib;

    bytes32 constant public CFA_ID = keccak256("org.superfluid-finance.agreements.ConstantFlowAgreement.v1");

    ISuperToken private _acceptedToken; // accepted token
    address public _landlord;
    address public _underwriter;
    int96 public _premiumRate;

    constructor(
        ISuperfluid host,
        ISuperToken acceptedToken,
        address landlord,
        address underwriter,
        int96 premiumRate
    ) {
        assert(address(host) != address(0));
        assert(address(acceptedToken) != address(0));
        assert(address(landlord) != address(0));

        _acceptedToken = acceptedToken;
        _landlord = landlord;
        _underwriter = underwriter;
        _premiumRate = premiumRate;

        cfaV1Lib = CFAv1Library.InitData(
            host,
            IConstantFlowAgreementV1(
                address(host.getAgreementClass(CFA_ID))
            )
        );

        uint256 configWord = SuperAppDefinitions.APP_LEVEL_FINAL |
            // change from 'before agreement stuff to after agreement
            SuperAppDefinitions.BEFORE_AGREEMENT_CREATED_NOOP |
            SuperAppDefinitions.BEFORE_AGREEMENT_UPDATED_NOOP |
            SuperAppDefinitions.BEFORE_AGREEMENT_TERMINATED_NOOP;

        host.registerApp(configWord);
    }

    function createFlowAndCollectPremiumWithCtx(
        bytes calldata ctx
        ) 
        private 
        returns (bytes memory newCtx)
    {
        (, int96 inFlowRate, , ) = cfaV1Lib.cfa.getFlow(
            _acceptedToken,
            msg.sender,
            address(this)
        );

        cfaV1Lib.createFlowWithCtx(ctx, _landlord, _acceptedToken, inFlowRate * (1 - _premiumRate));
        cfaV1Lib.createFlowWithCtx(newCtx, _underwriter, _acceptedToken,inFlowRate * _premiumRate);
    }

    function createFlowAndStreamToEndReceiverWithCtx(
        bytes calldata ctx
        ) 
        private 
        returns (bytes memory newCtx)
    {
        (, int96 inFlowRate, , ) = cfaV1Lib.cfa.getFlow(
            _acceptedToken,
            msg.sender,
            address(this)
        );

        cfaV1Lib.createFlowWithCtx(ctx, _landlord, _acceptedToken, inFlowRate);
    }


    /**************************************************************************
     * SuperApp callbacks
    *************************************************************************/
    
    function afterAgreementCreated(
        ISuperToken _superToken,
        address _agreementClass,
        bytes32, // _agreementId,
        bytes calldata /*_agreementData*/,
        bytes calldata ,// _cbdata,
        bytes calldata _ctx
    )
        external override
        onlyExpected(_superToken, _agreementClass)
        onlyHost
        returns (bytes memory newCtx)
    {
        //passing in the ctx which is sent to the callback here
        //createFlowAndCollectPremiumWithCtx makes use of callAgreementWithContext
        return createFlowAndCollectPremiumWithCtx(_ctx);
    }

    function afterAgreementTerminated(
        ISuperToken _superToken,
        address _agreementClass,
        bytes32, // _agreementId,
        bytes calldata /*_agreementData*/,
        bytes calldata ,// _cbdata,
        bytes calldata _ctx
    )
        external override
        onlyExpected(_superToken, _agreementClass)
        onlyHost
        returns (bytes memory newCtx)
    {
        //passing in the ctx which is sent to the callback here
        //createFlowAndCollectPremiumWithCtx makes use of callAgreementWithContext
        return createFlowAndStreamToEndReceiverWithCtx(ctx);(_ctx);
    }


    /**
    Logic for compatibility 
    */

    function _isSameToken(ISuperToken superToken) private view returns (bool) {
        return address(superToken) == address(_acceptedToken);
    }

    function _isCFAv1(address agreementClass) private view returns (bool) {
        return ISuperAgreement(agreementClass).agreementType() == CFA_ID;
    }

    modifier onlyHost() {
        require(
            msg.sender == address(cfaV1Lib.host),
            "RedirectAll: support only one host"
        );
        _;
    }

    modifier onlyExpected(ISuperToken superToken, address agreementClass) {
        require(_isSameToken(superToken), "RedirectAll: not accepted token");
        require(_isCFAv1(agreementClass), "RedirectAll: only CFAv1 supported");
        _;
    }
}
