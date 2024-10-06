// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Import necessary OpenZeppelin contracts
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title BottleUp Contract
/// @notice This contract allows users to submit bottles for rewards in the form of ERC20 tokens.
/// @dev The contract owner can manage admins, and admins can collect and reward tokens to users.
contract BottleUp is Ownable {
    // Enum representing the status of a bottle submission
    enum BottleStatus {
        Pending,    // Submission is pending verification
        Collected,  // Submission has been verified and collected
        Rewarded    // Tokens have been rewarded for this submission
    }

    // Structure representing a user profile
    struct UserProfile {
        address userAddress;              // Address of the user
        string username;                  // Username of the user
        uint256 totalBottlesSubmitted;    // Total number of bottles submitted by the user
        uint256 totalBottlesCollected;     // Total number of bottles collected
        uint256 totalBottlesRewarded;      // Total number of bottles rewarded with tokens
        uint256 tokenBalance;              // User's balance of reward tokens
    }

    // Structure representing a bottle submission
    struct BottleSubmission {
        uint256 bottleCount;               // Number of bottles submitted in this submission
        BottleStatus status;               // Current status of the submission
    }

    // Mapping of user addresses to their profiles
    mapping(address => UserProfile) public users;

    // Mapping of user addresses to their bottle submissions
    mapping(address => BottleSubmission[]) public userSubmissions;

    // Mapping to check if a user is registered
    mapping(address => bool) public isRegistered;

    // Array of registered user addresses for leaderboard purposes
    address[] public userList;

    // ERC20 token for rewarding users
    ERC20 public rewardToken;

    // Conversion rate of bottles to tokens
    uint256 public constant BOTTLES_PER_TOKEN = 10;

    // Mapping to manage admin addresses
    mapping(address => bool) public admins;

    /// @notice Contract constructor
    /// @param _rewardToken Address of the ERC20 token contract to be used for rewards
    constructor(address _rewardToken) Ownable(msg.sender) {
        rewardToken = ERC20(_rewardToken);
        admins[msg.sender] = true; // Owner is also an admin
    }

    // Modifier to restrict access to admin functions
    modifier onlyAdmin() {
        require(admins[msg.sender] || msg.sender == owner(), "Not an admin");
        _;
    }

    /// @notice Adds a new admin
    /// @param _admin Address of the new admin to add
    function addAdmin(address _admin) external onlyOwner {
        require(_admin != address(0), "Invalid admin address");
        admins[_admin] = true;
    }

    /// @notice Removes an admin
    /// @param _admin Address of the admin to remove
    function removeAdmin(address _admin) external onlyOwner {
        require(admins[_admin], "Address is not an admin");
        admins[_admin] = false;
    }

    /// @notice Registers a user with a username
    /// @param _username The username of the user
    function registerUser(string memory _username) public {
        require(!isRegistered[msg.sender], "User already registered");

        // Create a new user profile
        users[msg.sender] = UserProfile({
            userAddress: msg.sender,
            username: _username,
            totalBottlesSubmitted: 0,
            totalBottlesCollected: 0,
            totalBottlesRewarded: 0,
            tokenBalance: 0
        });

        // Mark user as registered
        isRegistered[msg.sender] = true;

        // Add user address to the user list for leaderboard
        userList.push(msg.sender);
    }

    /// @notice Allows a user to submit bottles for collection
    /// @param bottleCount The number of bottles being submitted
    function submitBottles(uint256 bottleCount) public {
        require(isRegistered[msg.sender], "User not registered");
        require(bottleCount > 0, "Bottle count must be greater than zero");

        // Update user's total submitted bottles
        users[msg.sender].totalBottlesSubmitted += bottleCount;

        // Add new submission to the user's submissions list
        userSubmissions[msg.sender].push(
            BottleSubmission({
                bottleCount: bottleCount,
                status: BottleStatus.Pending
            })
        );
    }

    /// @notice Admin marks bottles as collected for a user
    /// @param user Address of the user whose bottles are being collected
    /// @param submissionIndex Index of the submission being collected
    function collectBottles(address user, uint256 submissionIndex) public onlyAdmin {
        require(isRegistered[user], "User not registered");
        require(submissionIndex < userSubmissions[user].length, "Invalid submission index");
        require(userSubmissions[user][submissionIndex].status == BottleStatus.Pending, "Bottles already collected");

        // Update submission status to Collected
        userSubmissions[user][submissionIndex].status = BottleStatus.Collected;

        // Update user's total collected bottles
        users[user].totalBottlesCollected += userSubmissions[user][submissionIndex].bottleCount;
    }

    /// @notice Redeems tokens based on collected bottles
    function redeemTokens() public {
        require(isRegistered[msg.sender], "User not registered");

        uint256 totalCollectedBottles = users[msg.sender].totalBottlesCollected - users[msg.sender].totalBottlesRewarded;
        require(totalCollectedBottles >= BOTTLES_PER_TOKEN, "Not enough collected bottles to redeem tokens");

        // Calculate the number of tokens to redeem
        uint256 tokensToRedeem = totalCollectedBottles / BOTTLES_PER_TOKEN;

        // Update user's profile
        users[msg.sender].totalBottlesRewarded += tokensToRedeem * BOTTLES_PER_TOKEN;
        users[msg.sender].tokenBalance += tokensToRedeem;

        // Transfer reward tokens to the user
        rewardToken.transfer(msg.sender, tokensToRedeem * (10 ** 18)); // Assuming 18 decimals

        // Update status of rewarded submissions
        for (uint256 i = 0; i < userSubmissions[msg.sender].length; i++) {
            if (userSubmissions[msg.sender][i].status == BottleStatus.Collected) {
                userSubmissions[msg.sender][i].status = BottleStatus.Rewarded;
            }
        }
    }

    /// @notice Allows admins to withdraw reward tokens from the contract
    /// @param amount The amount of tokens to withdraw
    function withdrawRewardTokens(uint256 amount) external onlyAdmin {
        require(rewardToken.balanceOf(address(this)) >= amount, "Insufficient reward tokens in contract");
        rewardToken.transfer(msg.sender, amount);
    }

    /// @notice Allows admins to withdraw Ether from the contract
    /// @param amount The amount of Ether to withdraw
    function withdrawEther(uint256 amount) external onlyAdmin {
        require(address(this).balance >= amount, "Insufficient ether balance");
        payable(msg.sender).transfer(amount);
    }

    /// @notice Retrieves all bottle submissions for a user
    /// @param user Address of the user
    /// @return An array of BottleSubmission objects
    function getUserSubmissions(address user) public view returns (BottleSubmission[] memory) {
        return userSubmissions[user];
    }

    /// @notice Retrieves the top users by bottles collected for a leaderboard
    /// @param count The number of top users to retrieve
    /// @return An array of UserProfile objects representing the top users
    function getTopUsers(uint256 count) public view returns (UserProfile[] memory) {
        require(count > 0 && count <= userList.length, "Invalid count");

        // Create a local array of user addresses for sorting purposes
        address[] memory sortedUsers = new address[](userList.length);
        for (uint256 i = 0; i < userList.length; i++) {
            sortedUsers[i] = userList[i];
        }

        // Create a local array to store top user profiles
        UserProfile[] memory topUsers = new UserProfile[](count);

        // Sort users based on totalBottlesCollected (simple selection sort on local array)
        for (uint256 i = 0; i < sortedUsers.length; i++) {
            for (uint256 j = i + 1; j < sortedUsers.length; j++) {
                if (users[sortedUsers[j]].totalBottlesCollected > users[sortedUsers[i]].totalBottlesCollected) {
                    address temp = sortedUsers[i];
                    sortedUsers[i] = sortedUsers[j];
                    sortedUsers[j] = temp;
                }
            }
        }

        // Return the top `count` users
        for (uint256 k = 0; k < count; k++) {
            topUsers[k] = users[sortedUsers[k]];
        }

        return topUsers;
    }
}
