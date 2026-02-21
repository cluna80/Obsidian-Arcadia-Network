// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MovieNFT is ERC721, Ownable {
    
    uint256 private _movieIds;
    
    struct Movie {
        uint256 movieId;
        string title;
        string ipfsHash;
        address director;
        uint256[] sceneIds;
        uint256[] actorIds;
        uint256 productionCost;
        uint256 totalRevenue;
        uint256 releaseDate;
        Genre genre;
        Rating rating;
        bool isPublished;
    }
    
    struct RevenueShare {
        address[] recipients;
        uint256[] shares;
    }
    
    enum Genre {Action, Comedy, Drama, Horror, SciFi, Documentary, Animation, Thriller}
    enum Rating {G, PG, PG13, R, NC17}
    
    mapping(uint256 => Movie) public movies;
    mapping(uint256 => RevenueShare) private _revenueShares;
    
    event MovieMinted(uint256 indexed movieId, string title, address indexed director);
    event SceneAdded(uint256 indexed movieId, uint256 sceneId);
    event MoviePublished(uint256 indexed movieId, uint256 releaseDate);
    event RevenueDistributed(uint256 indexed movieId, uint256 amount);
    
    constructor() ERC721("OAN Movie", "MOVIE") Ownable(msg.sender) {}
    
    function mintMovie(
        string memory title,
        string memory ipfsHash,
        address director,
        Genre genre
    ) external returns (uint256) {
        _movieIds++;
        uint256 movieId = _movieIds;
        _safeMint(msg.sender, movieId);
        movies[movieId] = Movie(movieId,title,ipfsHash,director,new uint256[](0),new uint256[](0),0,0,0,genre,Rating.PG13,false);
        emit MovieMinted(movieId, title, director);
        return movieId;
    }
    
    function addScene(uint256 movieId, uint256 sceneId) external {
        require(ownerOf(movieId) == msg.sender, "Not owner");
        Movie storage movie = movies[movieId];
        require(!movie.isPublished, "Already published");
        movie.sceneIds.push(sceneId);
        emit SceneAdded(movieId, sceneId);
    }
    
    function setRevenueShares(uint256 movieId, address[] memory recipients, uint256[] memory shares) external {
        require(ownerOf(movieId) == msg.sender, "Not owner");
        require(recipients.length == shares.length, "Length mismatch");
        uint256 totalShares = 0;
        for(uint i = 0; i < shares.length; i++) {totalShares += shares[i];}
        require(totalShares == 10000, "Shares must sum to 100%");
        _revenueShares[movieId] = RevenueShare(recipients, shares);
    }
    
    function publishMovie(uint256 movieId) external {
        require(ownerOf(movieId) == msg.sender, "Not owner");
        Movie storage movie = movies[movieId];
        require(!movie.isPublished, "Already published");
        require(movie.sceneIds.length > 0, "No scenes");
        movie.isPublished = true;
        movie.releaseDate = block.timestamp;
        emit MoviePublished(movieId, block.timestamp);
    }
    
    function distributeRevenue(uint256 movieId) external payable {
        Movie storage movie = movies[movieId];
        require(movie.isPublished, "Not published");
        movie.totalRevenue += msg.value;
        RevenueShare storage shares = _revenueShares[movieId];
        for(uint i = 0; i < shares.recipients.length; i++) {
            uint256 amount = (msg.value * shares.shares[i]) / 10000;
            payable(shares.recipients[i]).transfer(amount);
        }
        emit RevenueDistributed(movieId, msg.value);
    }
    
    function getMovie(uint256 movieId) external view returns (Movie memory) {
        return movies[movieId];
    }
    
    function getRevenueShares(uint256 movieId) external view returns (address[] memory, uint256[] memory) {
        RevenueShare storage shares = _revenueShares[movieId];
        return (shares.recipients, shares.shares);
    }
}
