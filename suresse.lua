WebBanking{version     = 1.00,
           url         = "https://secure.suressedirektbank.de",
           services    = {"Suresse Direkt Bank"},
           country     = "de",
           description = "Tagesgeldkonto bei Suresse Direkt Bank"}

function SupportsBank (protocol, bankCode)
    return bankCode == "Suresse Direkt Bank" and protocol == ProtocolWebBanking
end

local connection = Connection()
local suresseBic = 'BSCHBEBBRET'

function InitializeSession (protocol, bankCode, username, reserved, password)
    local sessionData = '{"language":"de","securityContext":{"businessChannel":"B2C","company":7,"authenticationType":"PWD","communicationMode":"URL","deviceType":"DSK","project":"SOPRABANKING"},"user":{"loginName":"' .. username .. '"}}'
    connection:request("POST", url .. '/xclde/webapi/login/1/usersession', sessionData, "application/json")
    local authData = '{"dataMap":{"code":"' .. password .. '"}}'
    local authResponse = JSON(connection:request("POST", url .. '/xclde/webapi/login/1/usersession/authenticate', authData, "application/json")):dictionary()["UserSessionImpl"]
    if authResponse.isError == true then
        return authResponse.error.localizedMessage
    end
    local principalID = authResponse.user.userId
    jsonAccounts = JSON(connection:get(url .. '/xclde/webapi/b2crestapi/1/principaltocashaccountlinks?principalIdentification=' .. principalID .. '&retrieveAvailableAccountBalance=true')):dictionary()["PrincipalToCashAccountLinkOrder"]["goalList"]
end


function ListAccounts (knownAccounts)
    return getAccounts()
end

function RefreshAccount (account, since)
    return {balance=getBalance(account), transactions=getTransactions(account)}
end

function EndSession ()
    connection:request("POST", url .. '/xclde/webapi/login/1/usersession/close', '')
end

function getAccounts()
    local accounts = {}
    local productName = ''
    for key, value in pairs(jsonAccounts) do
        if string.match(value.bankProductWording, "Sparkonto") then
            productName = 'Tagesgeldkonto'
            accounts[#accounts+1] = {
                name = productName,
                owner = value.cashAccountClientWording,
                iban = value.accountNumber,
                bic = suresseBic,
                currency = value.valuationCurrency,
                type = AccountTypeSavings
            }
        end
    end

    if next(accounts) == nil then
        return 'No savings accounts found!'
    else
        return accounts
    end
end

function getTransactions(account)
    local jsonTransacts = JSON(connection:get(url .. '/xclde/webapi/b2crestapi/1/accountingmovements?accountNumber=' .. account.iban .. '&start=0&maxResults=100&creditOperation=Y&debitOperation=Y')):dictionary()["AccountingMovementOrder"]["goalList"]
    local transactions = {}
    local bookingtxt = ''
    for key, value in pairs(jsonTransacts) do
        if value.movementSign == 'D' then
            bookingtxt = 'Gutschrift'
        elseif value.movementSign == 'C' then
            bookingtxt = 'Überweisung'
        end
        transactions[#transactions+1] = {
            name = value.counterpartyName,
            accountNumber = value.operationCounterparty,
            currency = value.orderCurrency,
            purpose = value.communicationPart1,
            bookingText = bookingtxt,
            endToEndReference = value.operationReference,
            valueDate = os.time{year=value.valueDate:sub(1,4), month=value.valueDate:sub(5,6), day=value.valueDate:sub(-2)},
            bookingDate = os.time{year=value.accountingDate:sub(1,4), month=value.accountingDate:sub(5,6), day=value.accountingDate:sub(-2)},
            amount = value.orderAmount
        }
    end
    return transactions
end

function getBalance(account)
    local balance = 0
    for key, value in pairs(jsonAccounts) do
        if value.accountNumber == account.iban then
            balance = value.currentBalance
        end
    end
    return balance
end

