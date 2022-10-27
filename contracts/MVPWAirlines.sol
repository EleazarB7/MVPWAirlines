// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/a1948250ab8c441f6d327a65754cb20d2b1b4554/contracts/access/Ownable2Step.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";

 
 contract MVPWAirlines is Ownable2Step {
       
       // Information about the plane
       struct Plane {
            uint256 ecoClassSeats;
            uint256 firstClassSeats;
            bool isOnHold;
            bool isRegistered;
       }

       // Information about the Flight
       struct Flight {
            uint256 departureTime;
            uint256 priceForEcoSeats;
            uint256 priceForFirstClassSeats;
            uint256 ecoClassSeatsAvaliable;
            uint256 firstClassSeatsAvaliable;
            uint256 planeID;
            mapping(address => Reservation) reservations;
       }

       // Information about the number of tickets a person has reserved
       struct Reservation {
            uint256 ecoClassSeatsReserved;
            uint256 firstClassSeatsReserved;
       }
       
       
       address public tokenAddress; // Address of the token

       mapping(uint256 => Plane) public planes;
       mapping(uint256 => Flight) public flights;
      

      constructor(address _tokenAddress) {
             tokenAddress = _tokenAddress;
       }

       // Event signifying that a new plane is registered 
       event PlaneRegistered(uint256 planeID, uint256 ecoClassAvaliable, uint256 firstClassSeatsAvaliable);
       event PlaneOnHold(uint256 planeID); // Event signifying that a plane is put on hold
       event PlaneOffHold(uint256 planeID); // Event signifying that a plane is put off hold
       // Event signifying that a new flight is announced
       event FlightAnnounced(
             uint256 indexed planeID,
             uint256 indexed flightID,
             uint256 departureTime,
             uint256 priceForEcoSeats,
             uint256 priceForFirstClassSeats,
             uint256 ecoClassSeatsAvaliable,
             uint256 firstClassSeatsAvaliable,
             string destination);
       // Event signifying that tickets have been bought     
       event TicketsBought(uint256 indexed flightID, address indexed buyer, uint256 numberOfEcoClassSeats, uint256 numberOfFirstClassSeats);
       // Event signifying that thickets have been canceled
       event TicketsCanceled(uint256 indexed flightID, address indexed buyer, uint256 numberOfEcoClassSeats, uint256 numberOfFirstClassSeats);
            
        
       error PlaneIDValid(uint256 planeID); // Error signifying that the plane id is valid
       error FlightIDValid(uint256 flightID); // Error signifying that the flight id is valid
       error InvalidDepartureTime(uint256 departureTime); // Error signifying that the departure time si invalid
       error PlaneIsOnHold(); // Error signifying that a plane is on hold
       error PlaneNotFound(); // Error signifying that a plane is not found
       error FlightNotFound(); // Error signifying that a flight is not found
       error TicketsNotChosen(); // Error signifying that tickets have not been chosen
       error ToManyTicketsChosen(); // Error signifying that too many tickets have been chosen
       error AllowanceNotValid(); // Error signifying that allowance is not valid
       error NotEnoughBalance(); // Error signifying that balance is low

       // With this function we are registering a new plane
       function registerNewPlane(uint256 _planeID, uint256 _ecoClassSeats, uint256 _firstClassSeats) external onlyOwner {
             Plane memory plane = planes[_planeID];
             if (plane.isRegistered){
                   revert PlaneIDValid(_planeID);
             }

             plane.ecoClassSeats = _ecoClassSeats;
             plane.firstClassSeats = _firstClassSeats;
             plane.isRegistered = true;

             emit PlaneRegistered(_planeID, _ecoClassSeats, _firstClassSeats);
       }
       // With this function we are puting a plane on hold and flights are prevented from being announced 
       function putPlaneOnHold(uint256 _planeID) external onlyOwner{
             planes[_planeID].isOnHold = true;

             emit PlaneOnHold(_planeID);
       }
       // With this function we are puting a plane off hold and flights are allowed to be announced 
       function putPlaneOffHold(uint256 _planeID) external onlyOwner{
             planes[_planeID].isOnHold = false;

             emit PlaneOffHold(_planeID);
       }
       // With this function we are announcing a new Flight
       function newFlight(
             uint256 _flightID,
             uint256 _planeID,
             uint256 _priceForEcoSeats,
             uint256 _priceForFirstClassSeats,
             uint256 _departureTime,
             string memory _destination
       ) external onlyOwner{
          Flight storage flight = flights[_flightID];
          if (flight.departureTime != 0){
                revert FlightIDValid(_flightID);
          }

          Plane memory plane = planes[_planeID];

          if (!plane.isRegistered) {
                revert PlaneNotFound();
          }

          if (plane.isOnHold) {
                revert PlaneIsOnHold();
          }

          flight.departureTime = _departureTime;
          flight.priceForEcoSeats = _priceForEcoSeats;
          flight.priceForFirstClassSeats = _priceForFirstClassSeats;
          flight.planeID = _planeID;
          flight.ecoClassSeatsAvaliable = plane.ecoClassSeats;
          flight.firstClassSeatsAvaliable = plane.firstClassSeats;



          emit FlightAnnounced(
                _planeID,
                _flightID,
                _priceForEcoSeats,
                _priceForFirstClassSeats,
                plane.ecoClassSeats,
                plane.firstClassSeats,
                _departureTime,
                _destination

          );
       }
      // With this function a person is reserving tickets for the flight
       function reserveTickets(uint256 _flightID, uint256 _numberOfEcoClassSeats, uint256 _numberOfFirstClassSeats) external {
             if (_numberOfEcoClassSeats == 0 && _numberOfFirstClassSeats == 0) {
                   revert TicketsNotChosen();
             }

             Flight storage flight = flights[_flightID];
             Reservation storage reservation = flight.reservations[msg.sender];

             if (reservation.ecoClassSeatsReserved + reservation.firstClassSeatsReserved + _numberOfEcoClassSeats + _numberOfFirstClassSeats > 4){
                   revert ToManyTicketsChosen();
             }

       uint256 totalCost = _numberOfFirstClassSeats * flight.priceForFirstClassSeats;
       totalCost = _numberOfEcoClassSeats * flight.priceForEcoSeats;


       IERC20 tokenContract = IERC20(tokenAddress);
       if (tokenContract.allowance(msg.sender, address(this)) < totalCost) {
             revert AllowanceNotValid();
       }

       flight.ecoClassSeatsAvaliable -= _numberOfEcoClassSeats;
       flight.firstClassSeatsAvaliable -= _numberOfFirstClassSeats;

       reservation.ecoClassSeatsReserved += _numberOfEcoClassSeats;
       reservation.firstClassSeatsReserved += _numberOfFirstClassSeats;

       tokenContract.transferFrom(msg.sender, address(this), totalCost);

       emit TicketsBought(_flightID, msg.sender, _numberOfEcoClassSeats, _numberOfFirstClassSeats);

       }
       
       // With this function a person is cancelling tickets that he has reserved 
       function cancelTickets(uint256 _flightID, uint256 _numberOfEcoClassSeats, uint256 _numberOfFirstClassSeats) external{
             Flight storage flight = flights[_flightID];
             Reservation storage reservation = flight.reservations[msg.sender];
             uint256 refundSum;
             

             flight.ecoClassSeatsAvaliable += _numberOfEcoClassSeats;
             flight.firstClassSeatsAvaliable += _numberOfFirstClassSeats;

             reservation.ecoClassSeatsReserved -= _numberOfEcoClassSeats;
             reservation.firstClassSeatsReserved -= _numberOfFirstClassSeats;

             if (block.timestamp + 1 days < flight.departureTime) {
                   refundSum = _numberOfEcoClassSeats * flight.priceForEcoSeats;
                   refundSum += _numberOfFirstClassSeats * flight.priceForFirstClassSeats;
             }

             if (block.timestamp + 2 days > flight.departureTime){
                   refundSum = (refundSum / 5) * 4;
             }

      
             IERC20 tokenContract = IERC20(tokenAddress);
             if (tokenContract.balanceOf(address(this)) < refundSum) {
                   revert NotEnoughBalance();
             }

             emit TicketsCanceled(_flightID, msg.sender, _numberOfEcoClassSeats, _numberOfFirstClassSeats);

       }


 }
       
      
       
      
      



     
 
