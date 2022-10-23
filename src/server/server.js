import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import FlightSuretyData from '../../build/contracts/FlightSuretyData.json';
import Config from './config.json';
import Web3 from 'web3';
import express from 'express';

var cors = require('cors');

// List of flight
const flights = [
  {"id": 0, "name": "MGRT001"},
  {"id": 1, "name": "SBCT002"},
  {"id": 2, "name": "NGLT003"},
  {"id": 3, "name": "CGLT005"},
  {"id": 4, "name": "TENT007"},
  {"id": 5, "name": "KRLT009"}
]

let config = Config['localhost'];
let web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws')));
web3.eth.defaultAccount = web3.eth.accounts[0];
let flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
let flightSuretyData = new web3.eth.Contract(FlightSuretyData.abi, config.dataAddress);

let oracle_address = [];
let eventIndex = null;

//Initialize Oracles
function initOracles() {
  return new Promise((resolve, reject) => {
      web3.eth.getAccounts().then(accounts =>{
      let rounds = 20 
      let oracles = [];
      flightSuretyApp.methods.REGISTRATION_FEE().call().then(fee => {

        accounts.forEach(account => {
          flightSuretyApp.methods.registerOracle().send({
              from: account,
              value: fee,
              gas: 6721975,
              gasPrice: 10000
          }).then(() => {
              flightSuretyApp.methods.getMyIndexes().call({
                  from: account
              }).then(result => {
                  oracles.push(result);
                  oracle_address.push(account);
                  console.log(`Oracle Data: Index ${result[0]}, ${result[1]}, ${result[2]} using account ${account}`);
                  rounds -= 1;
                  if (!rounds) {
                      resolve(oracles);
                  }
              }).catch(err => {
                  reject(err);
              });
          }).catch(err => {
              reject(err);
          });
      });

      }).catch(err => {
          reject(err);
      });
      }).catch(err => {
        reject(err);
    });
  });
}

//Invoke Oracle Initialization
initOracles().then(oracles =>{
  console.log("Oracles Registered - Success");
  initializeAPI();

 flightSuretyApp.events.SubmitOracleResponse({
    fromBlock: "latest"
  }, function (error, event) {
      if (error) {
          console.log(error)
      }
      console.log(event);
      
      let airline = event.returnValues.airline;
      let flight = event.returnValues.flight;
      let timestamp = event.returnValues.timestamp;
      let indexes = event.returnValues.indexes;
      let statusCode = event.returnValues.statusCode;

      for(let a=0; a< oracle_address.length; a++){
          console.log("Oracle loop ",a);
          flightSuretyApp.methods
            .submitOracleResponse(indexes, airline, flight, timestamp, statusCode)
            .send({ 
              from: oracle_address[a] 
            }).then(result => {
              console.log(result);
          }).catch(err => {
            console.log("No response from Oracle");

          });
      }

  });

  flightSuretyApp.events.RegisterAirline({
    fromBlock: 0
  }, function (error, event) {
    if (error) console.log(error)
    console.log(event)
  });
  
  flightSuretyData.events.FundedAirLines({
    fromBlock: 0
  }, function (error, event) {
    if (error) console.log(error)
    console.log(event)
  });

  flightSuretyData.events.PurchaseInsurance({
    fromBlock: 0
  }, function (error, event) {
    if (error) console.log(error)
    console.log(event)
  });

  flightSuretyApp.events.CreditInsurees({
    fromBlock: 0
  }, function (error, event) {
    if (error) console.log(error)
    console.log(event)
  });

  flightSuretyData.events.Withdraw({
  fromBlock: 0
}, function (error, event) {
  if (error) console.log(error)
  console.log(event)
  });

  flightSuretyApp.events.OracleRequest({
    fromBlock: 0
  }, function (error, event) {
    if (error) console.log(error)

    eventIndex = event.returnValues.index;
    console.log(event)
  });

  flightSuretyApp.events.OracleReport({
  fromBlock: 0
}, function (error, event) {
  if (error) console.log(error)
  console.log(event)
  });
  
}).catch(err => {
  console.log(err.message);
})



//Initialize APP
const app = express();


//Initialize API server
function initializeAPI(){
 
  app.get('/api', (req, res) => {
    res.send({
      message: 'Success - Response for /api call'
    })
  })

  app.get('/flights', (req, res) => {
    res.json({
      result: flights
    })
  })
  
  app.get('/eventIndex', (req, res) => {
    res.json({
      result: eventIndex
    })
  }) 
  
  console.log("Success - API Initialize");

}

app.use(cors());

export default app;


