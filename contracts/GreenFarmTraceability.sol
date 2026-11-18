// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract GreenFarmTraceability {
    // สิทธิ์ของแต่ละบัญชี
    enum Role { None, Farmer, Transporter, Distributor, Admin }
    // สถานะการเดินทางของล็อต
    enum Stage { Harvested, InTransit, AtWarehouse, AtStore }
    // ประเภทเหตุการณ์ในประวัติ
    enum Action {
        Registered,
        HandoverOffered,
        HandoverAccepted,
        HandoverCancelled,
        StageUpdated,
        Recalled,
        RecallResolved,
        InspectionPassed,
        InspectionFailed,
        IssueReported
    }

    // ข้อมูลล็อตและสถานะล่าสุด
    struct Batch {
        string productName;
        uint64 harvestedAt;
        string origin;
        string certification;
        address farmer;
        address custodian;
        address pendingRecipient;
        Stage stage;
        bool recalled;
        string recallReason;
    }

    // ข้อมูลของเหตุการณ์หนึ่งรายการ
    struct HistoryEntry {
        Action action;
        uint64 timestamp;
        address actor;
        address counterparty;
        Stage stage;
        string note;
    }

    // เก็บผู้ดูแลหลัก สิทธิ์บัญชี ข้อมูลล็อต และประวัติ
    address public immutable administrator;
    mapping(address => Role) public roles;
    mapping(string => Batch) private batches;
    mapping(string => HistoryEntry[]) private history;

    // แจ้งเมื่อสิทธิ์บัญชีหรือข้อมูลล็อตเปลี่ยน
    event StakeholderUpdated(address indexed account, Role previousRole, Role newRole);
    event BatchActivity(string indexed batchKey, uint256 indexed entryIndex, Action indexed action, string batchId);

    // ให้บัญชีที่ deploy เป็นผู้ดูแลหลัก
    constructor() {
        administrator = msg.sender;
        roles[msg.sender] = Role.Admin;
        emit StakeholderUpdated(msg.sender, Role.None, Role.Admin);
    }

    // ให้ผู้ดูแลหลักกำหนดหรือถอนสิทธิ์ของบัญชีอื่น
    function setStakeholder(address account, Role role) external {
        require(msg.sender == administrator, "Deployer only");
        require(account != address(0) && account != administrator, "Invalid account");
        Role previousRole = roles[account];
        roles[account] = role;
        emit StakeholderUpdated(account, previousRole, role);
    }

    // ให้เกษตรกรสร้างล็อตใหม่และเป็นผู้ครอบครองคนแรก
    function registerBatch(
        string calldata batchId,
        string calldata productName,
        uint64 harvestedAt,
        string calldata origin,
        string calldata certification
    ) external {
        require(roles[msg.sender] == Role.Farmer, "Farmer only");
        require(bytes(batchId).length > 0 && bytes(batchId).length <= 64, "Invalid batch ID");
        require(batches[batchId].farmer == address(0), "Batch already exists");
        require(harvestedAt > 0 && harvestedAt <= block.timestamp, "Invalid harvest time");
        require(bytes(productName).length > 0 && bytes(origin).length > 0, "Product and origin required");
        require(bytes(certification).length > 0, "Certification required");

        Batch storage batch = batches[batchId];
        batch.productName = productName;
        batch.harvestedAt = harvestedAt;
        batch.origin = origin;
        batch.certification = certification;
        batch.farmer = msg.sender;
        batch.custodian = msg.sender;
        _record(batchId, Action.Registered, address(0), "");
    }

    // ให้ผู้ครอบครองระบุว่าจะส่งล็อตให้ใคร
    function offerHandover(string calldata batchId, address recipient) external {
        Batch storage batch = _getBatch(batchId);
        require(!batch.recalled, "Batch under recall");
        require(msg.sender == batch.custodian && _isSupplyChainActor(msg.sender), "Active custodian only");
        require(batch.pendingRecipient == address(0), "Handover already pending");
        require(recipient != msg.sender && _isSupplyChainActor(recipient), "Invalid recipient");

        batch.pendingRecipient = recipient;
        _record(batchId, Action.HandoverOffered, recipient, "");
    }

    // ให้ผู้รับที่ระบุยืนยันก่อนที่ล็อตจะเปลี่ยนมือ
    function acceptHandover(string calldata batchId) external {
        Batch storage batch = _getBatch(batchId);
        require(!batch.recalled, "Batch under recall");
        require(msg.sender == batch.pendingRecipient && _isSupplyChainActor(msg.sender), "Active named recipient only");
        address previousCustodian = batch.custodian;
        require(_isSupplyChainActor(previousCustodian), "Sender role inactive");

        batch.custodian = msg.sender;
        batch.pendingRecipient = address(0);
        _record(batchId, Action.HandoverAccepted, previousCustodian, "");
    }

    // ให้ผู้ส่ง ผู้รับ หรือแอดมินยกเลิกคำขอที่ค้าง
    function cancelHandover(string calldata batchId) external {
        Batch storage batch = _getBatch(batchId);
        address recipient = batch.pendingRecipient;
        require(recipient != address(0), "No pending handover");
        require(msg.sender == batch.custodian || msg.sender == recipient || roles[msg.sender] == Role.Admin, "Cannot cancel");
        batch.pendingRecipient = address(0);
        _record(batchId, Action.HandoverCancelled, recipient, "");
    }

    // ให้ผู้ครอบครองอัปเดตสถานะไปข้างหน้า
    function updateStage(string calldata batchId, Stage newStage, string calldata note) external {
        Batch storage batch = _getBatch(batchId);
        require(!batch.recalled, "Batch under recall");
        require(msg.sender == batch.custodian && _isSupplyChainActor(msg.sender), "Active custodian only");
        require(uint8(newStage) > uint8(batch.stage), "Stage must advance");

        batch.stage = newStage;
        _record(batchId, Action.StageUpdated, address(0), note);
    }

    // ให้ผู้ครอบครองบันทึกว่าตรวจผ่านไหม พร้อมรายละเอียด
    function recordInspection(string calldata batchId, bool passed, string calldata note) external {
        Batch storage batch = _getBatch(batchId);
        require(msg.sender == batch.custodian && _isSupplyChainActor(msg.sender), "Active custodian only");
        require(bytes(note).length > 0, "Inspection note required");

        Action action = passed ? Action.InspectionPassed : Action.InspectionFailed;
        _record(batchId, action, address(0), note);
    }

    // ให้ผู้ครอบครองลงรายงานปัญหาไว้ให้แอดมินตรวจ
    function reportIssue(string calldata batchId, string calldata reason) external {
        Batch storage batch = _getBatch(batchId);
        require(msg.sender == batch.custodian && _isSupplyChainActor(msg.sender), "Active custodian only");
        require(bytes(reason).length > 0, "Issue reason required");

        _record(batchId, Action.IssueReported, address(0), reason);
    }

    // ให้แอดมินเรียกคืนล็อตพร้อมระบุเหตุผล
    function recallBatch(string calldata batchId, string calldata reason) external {
        Batch storage batch = _getBatch(batchId);
        require(roles[msg.sender] == Role.Admin, "Admin only");
        require(!batch.recalled, "Already recalled");
        require(bytes(reason).length > 0, "Recall reason required");

        // ปิดคำขอส่งมอบที่ค้างอยู่เมื่อเรียกคืน
        if (batch.pendingRecipient != address(0)) {
            address recipient = batch.pendingRecipient;
            batch.pendingRecipient = address(0);
            _record(batchId, Action.HandoverCancelled, recipient, "Cancelled by recall");
        }
        batch.recalled = true;
        batch.recallReason = reason;
        _record(batchId, Action.Recalled, address(0), reason);
    }

    // ให้แอดมินปิดการเรียกคืนพร้อมบันทึกผล
    function resolveRecall(string calldata batchId, string calldata resolution) external {
        Batch storage batch = _getBatch(batchId);
        require(roles[msg.sender] == Role.Admin, "Admin only");
        require(batch.recalled, "No active recall");
        require(bytes(resolution).length > 0, "Resolution required");

        batch.recalled = false;
        delete batch.recallReason;
        _record(batchId, Action.RecallResolved, address(0), resolution);
    }

    // อ่านข้อมูลและสถานะล่าสุดของล็อต
    function getBatch(string calldata batchId) external view returns (Batch memory) {
        return _getBatch(batchId);
    }

    // ดูว่าล็อตนี้มีประวัติกี่รายการ
    function getHistoryCount(string calldata batchId) external view returns (uint256) {
        _getBatch(batchId);
        return history[batchId].length;
    }

    // อ่านประวัติทีละรายการ โดยเริ่มที่เลข 0
    function getHistoryEntry(string calldata batchId, uint256 index) external view returns (HistoryEntry memory) {
        _getBatch(batchId);
        require(index < history[batchId].length, "History entry not found");
        return history[batchId][index];
    }

    // หาล็อตจากรหัสและแจ้งถ้าหาไม่เจอ
    function _getBatch(string calldata batchId) private view returns (Batch storage batch) {
        batch = batches[batchId];
        require(batch.farmer != address(0), "Batch not found");
    }

    // เช็กว่าบัญชีมีสิทธิ์ส่งหรือรับล็อต
    function _isSupplyChainActor(address account) private view returns (bool) {
        Role role = roles[account];
        return role == Role.Farmer || role == Role.Transporter || role == Role.Distributor;
    }

    // เพิ่มเหตุการณ์ใหม่ต่อท้ายประวัติ
    function _record(string calldata batchId, Action action, address counterparty, string memory note) private {
        HistoryEntry[] storage entries = history[batchId];
        entries.push(HistoryEntry(action, uint64(block.timestamp), msg.sender, counterparty, batches[batchId].stage, note));
        emit BatchActivity(batchId, entries.length - 1, action, batchId);
    }
}