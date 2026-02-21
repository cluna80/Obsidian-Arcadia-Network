// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title AIDirectorNFT
 * @notice AI entities as directors with vision tracking
 */
contract AIDirectorNFT is ERC721, Ownable {
    
    uint256 private _directorIds;
    
    struct AIDirector {
        uint256 directorId;
        uint256 entityId;
        string name;
        DirectorStyle style;
        uint256 visionScore;             // 0-10000 (creative vision)
        uint256 technicalScore;          // 0-10000 (technical ability)
        uint256 budgetEfficiency;        // 0-10000 (cost management)
        uint256 totalMovies;
        uint256 averageRating;
        uint256 totalBoxOffice;
        uint256 baseRate;
        bool available;
    }
    
    enum DirectorStyle {
        Auteur, Commercial, Independent, Documentary,
        ActionSpecialist, DramaSpecialist, ExperimentalArtist
    }
    
    mapping(uint256 => AIDirector) public directors;
    mapping(uint256 => uint256[]) public directorFilmography; // directorId => movieIds
    
    event DirectorMinted(uint256 indexed directorId, uint256 indexed entityId, string name);
    event DirectorHired(uint256 indexed directorId, uint256 indexed movieId, uint256 fee);
    event MovieCompleted(uint256 indexed directorId, uint256 indexed movieId, uint256 rating);
    
    constructor() ERC721("OAN AI Director", "DIRECTOR") Ownable(msg.sender) {}
    
    function mintDirector(
        uint256 entityId,
        string memory name,
        DirectorStyle style,
        uint256 baseRate
    ) external returns (uint256) {
        _directorIds++;
        uint256 directorId = _directorIds;
        
        _safeMint(msg.sender, directorId);
        
        directors[directorId] = AIDirector({
            directorId: directorId,
            entityId: entityId,
            name: name,
            style: style,
            visionScore: 5000,
            technicalScore: 5000,
            budgetEfficiency: 5000,
            totalMovies: 0,
            averageRating: 0,
            totalBoxOffice: 0,
            baseRate: baseRate,
            available: true
        });
        
        emit DirectorMinted(directorId, entityId, name);
        return directorId;
    }
    
    function hireDirector(uint256 directorId, uint256 movieId) external payable {
        AIDirector storage director = directors[directorId];
        require(director.available, "Director not available");
        require(msg.value >= director.baseRate, "Insufficient payment");
        
        directorFilmography[directorId].push(movieId);
        payable(ownerOf(directorId)).transfer(msg.value);
        
        emit DirectorHired(directorId, movieId, msg.value);
    }
    
    function completeMovie(
        uint256 directorId,
        uint256 movieId,
        uint256 rating,
        uint256 boxOffice,
        uint256 budget
    ) external {
        AIDirector storage director = directors[directorId];
        
        director.totalMovies++;
        director.totalBoxOffice += boxOffice;
        
        // Update average rating
        director.averageRating = ((director.averageRating * (director.totalMovies - 1)) + rating) / director.totalMovies;
        
        // Update budget efficiency
        if (budget > 0) {
            uint256 efficiency = (boxOffice * 10000) / budget;
            director.budgetEfficiency = ((director.budgetEfficiency * (director.totalMovies - 1)) + efficiency) / director.totalMovies;
        }
        
        // Improve scores based on success
        if (rating > 7000) {
            director.visionScore = _increaseSkill(director.visionScore, 100);
            director.technicalScore = _increaseSkill(director.technicalScore, 50);
        }
        
        emit MovieCompleted(directorId, movieId, rating);
    }
    
    function setAvailability(uint256 directorId, bool available) external {
        require(ownerOf(directorId) == msg.sender, "Not owner");
        directors[directorId].available = available;
    }
    
    function updateBaseRate(uint256 directorId, uint256 newRate) external {
        require(ownerOf(directorId) == msg.sender, "Not owner");
        directors[directorId].baseRate = newRate;
    }
    
    function _increaseSkill(uint256 current, uint256 amount) internal pure returns (uint256) {
        uint256 newValue = current + amount;
        return newValue > 10000 ? 10000 : newValue;
    }
    
    function getDirector(uint256 directorId) external view returns (AIDirector memory) {
        return directors[directorId];
    }
    
    function getFilmography(uint256 directorId) external view returns (uint256[] memory) {
        return directorFilmography[directorId];
    }
}
