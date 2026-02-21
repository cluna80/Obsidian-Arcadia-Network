// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title TalentMarketplace
 * @notice Hire AI actors and directors for productions
 */
contract TalentMarketplace is Ownable, ReentrancyGuard {
    
    struct TalentListing {
        uint256 listingId;
        TalentType talentType;
        uint256 talentId;
        address owner;
        uint256 rate;
        bool exclusive;              // Can only work on one project at a time
        bool available;
        uint256 minProjectBudget;    // Minimum budget to hire
        uint256 totalBookings;
    }
    
    struct Booking {
        uint256 bookingId;
        uint256 listingId;
        uint256 movieId;
        address producer;
        uint256 fee;
        uint256 startDate;
        uint256 endDate;
        BookingStatus status;
    }
    
    enum TalentType {Actor, Director, Writer, Cinematographer, Editor}
    enum BookingStatus {Pending, Active, Completed, Cancelled}
    
    mapping(uint256 => TalentListing) public listings;
    mapping(uint256 => Booking) public bookings;
    
    uint256 public listingCount;
    uint256 public bookingCount;
    uint256 public platformFee = 250; // 2.5%
    
    event TalentListed(uint256 indexed listingId, TalentType talentType, uint256 talentId, uint256 rate);
    event TalentBooked(uint256 indexed bookingId, uint256 indexed listingId, uint256 movieId, uint256 fee);
    event BookingCompleted(uint256 indexed bookingId);
    
    constructor() Ownable(msg.sender) {}
    
    function listTalent(
        TalentType talentType,
        uint256 talentId,
        uint256 rate,
        bool exclusive,
        uint256 minProjectBudget
    ) external returns (uint256) {
        listingCount++;
        uint256 listingId = listingCount;
        
        listings[listingId] = TalentListing({
            listingId: listingId,
            talentType: talentType,
            talentId: talentId,
            owner: msg.sender,
            rate: rate,
            exclusive: exclusive,
            available: true,
            minProjectBudget: minProjectBudget,
            totalBookings: 0
        });
        
        emit TalentListed(listingId, talentType, talentId, rate);
        return listingId;
    }
    
    function bookTalent(
        uint256 listingId,
        uint256 movieId,
        uint256 durationDays
    ) external payable nonReentrant returns (uint256) {
        TalentListing storage listing = listings[listingId];
        require(listing.available, "Not available");
        
        uint256 totalFee = listing.rate * durationDays;
        require(msg.value >= totalFee, "Insufficient payment");
        
        bookingCount++;
        uint256 bookingId = bookingCount;
        
        bookings[bookingId] = Booking({
            bookingId: bookingId,
            listingId: listingId,
            movieId: movieId,
            producer: msg.sender,
            fee: totalFee,
            startDate: block.timestamp,
            endDate: block.timestamp + (durationDays * 1 days),
            status: BookingStatus.Active
        });
        
        if (listing.exclusive) {
            listing.available = false;
        }
        
        listing.totalBookings++;
        
        // Platform fee
        uint256 fee = (totalFee * platformFee) / 10000;
        uint256 ownerPayment = totalFee - fee;
        
        payable(listing.owner).transfer(ownerPayment);
        
        // Refund excess
        if (msg.value > totalFee) {
            payable(msg.sender).transfer(msg.value - totalFee);
        }
        
        emit TalentBooked(bookingId, listingId, movieId, totalFee);
        return bookingId;
    }
    
    function completeBooking(uint256 bookingId) external {
        Booking storage booking = bookings[bookingId];
        require(booking.producer == msg.sender, "Not producer");
        require(booking.status == BookingStatus.Active, "Not active");
        
        booking.status = BookingStatus.Completed;
        
        TalentListing storage listing = listings[booking.listingId];
        if (listing.exclusive) {
            listing.available = true;
        }
        
        emit BookingCompleted(bookingId);
    }
    
    function updateListing(uint256 listingId, uint256 newRate, bool available) external {
        TalentListing storage listing = listings[listingId];
        require(listing.owner == msg.sender, "Not owner");
        
        listing.rate = newRate;
        listing.available = available;
    }
    
    function getListing(uint256 listingId) external view returns (TalentListing memory) {
        return listings[listingId];
    }
    
    function getBooking(uint256 bookingId) external view returns (Booking memory) {
        return bookings[bookingId];
    }
}
