 create database BidNile;
go

use BidNile;
go

create schema Membership;
go
create schema Logistics;
go
create schema Catalog;
go
create schema Sales;
go

/* =====================================================================
   MEMBERSHIP
   ===================================================================== */

create table Membership.City
(
    CityId      int identity(1,1) not null,
    Name        nvarchar(60)      not null,
    CountryCode char(2)           not null,

    constraint PK_City              primary key (CityId),
    constraint CK_City_CountryCode  check (CountryCode in ('EG', 'SA', 'AE')),
    constraint UQ_City_Country_Name unique (CountryCode, Name)
);
go

create table Membership.Member
(
    MemberId          uniqueidentifier not null
        constraint DF_Member_MemberId default newid(),
    FullName          nvarchar(100)    not null,
    Email             varchar(254)     not null,
    Mobile            varchar(16)      not null,          
    NationalId        varchar(20)      not null,
    BirthDate         date             not null,
    IsVerified        bit              not null
        constraint DF_Member_IsVerified default 0,
    RegisteredAt      datetime2(3)     not null
        constraint DF_Member_RegisteredAt default sysutcdatetime(),
    CityId            int              not null,         
    InvitedByMemberId uniqueidentifier null,              

    constraint PK_Member            primary key (MemberId),
    constraint UQ_Member_Email      unique (Email),
    constraint UQ_Member_NationalId unique (NationalId),
    constraint CK_Member_BirthDate  check (BirthDate <= dateadd(year, -18, cast(sysdatetime() as date))),
    constraint CK_Member_NotSelfInvited check (InvitedByMemberId is null or InvitedByMemberId <> MemberId)
);
go

create table Membership.Wallet
(
    MemberId   uniqueidentifier not null,                 
    Balance    decimal(12,2)    not null
        constraint DF_Wallet_Balance default 0,
    HeldAmount decimal(12,2)    not null
        constraint DF_Wallet_HeldAmount default 0,
    Currency   char(3)          not null
        constraint DF_Wallet_Currency default 'EGP',
    UpdatedAt  datetime2(3)     not null
        constraint DF_Wallet_UpdatedAt default sysutcdatetime(),

    constraint PK_Wallet            primary key (MemberId),
    constraint CK_Wallet_Balance    check (Balance >= 0),
    constraint CK_Wallet_HeldAmount check (HeldAmount >= 0 and HeldAmount <= Balance)
);
go

/* =====================================================================
   LOGISTICS
   ===================================================================== */

create table Logistics.Warehouse
(
    WarehouseId  int identity(1,1) not null,
    Name         nvarchar(80)      not null,
    Capacity     int               not null,
    CityId       int               not null,             
    Latitude     float             not null,
    Longitude    float             not null,
    ManagerId    uniqueidentifier  null,                  
    ManagerSince date              null,

    constraint PK_Warehouse           primary key (WarehouseId),
    constraint UQ_Warehouse_Name      unique (Name),
    constraint CK_Warehouse_Capacity  check (Capacity > 0),
    constraint CK_Warehouse_Latitude  check (Latitude  between -90  and 90),
    constraint CK_Warehouse_Longitude check (Longitude between -180 and 180)
);
go


create unique nonclustered index UQ_Warehouse_ManagerId
    on Logistics.Warehouse (ManagerId)
    where ManagerId is not null;
go

create table Logistics.Employee
(
    MemberId    uniqueidentifier not null,                
    WarehouseId int              not null,                

    constraint PK_Employee primary key (MemberId)
);
go

/* =====================================================================
   CATALOG
   ===================================================================== */

create table Catalog.Category
(
    CategoryId       int           not null,              
    NameEn           varchar(50)   not null,
    NameAr           nvarchar(50)  null,
    CommissionPct    decimal(4,2)  not null,
    ParentCategoryId int           null,                  

    constraint PK_Category               primary key (CategoryId),
    constraint UQ_Category_NameEn        unique (NameEn),
    constraint CK_Category_CommissionPct check (CommissionPct between 0 and 30)
);
go

create table Catalog.Item
(
    ItemId         int identity(1,1) not null,
    Title          nvarchar(150)     not null,
    Description    nvarchar(max)     null,
    ConditionScore tinyint           not null,
    Specs          json              not null,           
    ListedAt       datetime2(3)      not null
        constraint DF_Item_ListedAt default sysutcdatetime(),
    SellerId       uniqueidentifier  not null,              
    InspectorId    uniqueidentifier  null,                  
    CategoryId     int               not null,              
    WarehouseId    int               null,                  

    constraint PK_Item                    primary key (ItemId),
    constraint CK_Item_ConditionScore     check (ConditionScore between 1 and 10),
    constraint CK_Item_SellerNotInspector check (InspectorId is null or InspectorId <> SellerId)
);
go

create table Catalog.ItemPhoto
(
    ItemId  int          not null,                        
    PhotoNo tinyint      not null,                        
    Url     varchar(500) not null,
    IsMain  bit          not null
        constraint DF_ItemPhoto_IsMain default 0,

    constraint PK_ItemPhoto         primary key (ItemId, PhotoNo),
    constraint CK_ItemPhoto_PhotoNo check (PhotoNo between 1 and 20)
);
go

/* =====================================================================
   SALES
   ===================================================================== */

create table Sales.Auction
(
    AuctionId    int identity(1,1) not null,
    ItemId       int               not null,              
    StartPrice   decimal(12,2)     not null,
    ReservePrice decimal(12,2)     null,
    BidIncrement decimal(12,2)     not null
        constraint DF_Auction_BidIncrement default 50.00,
    StartsAt     datetimeoffset(0) not null,
    EndsAt       datetimeoffset(0) not null,
    Status       varchar(20)       not null
        constraint DF_Auction_Status default 'Draft',

    constraint PK_Auction                primary key (AuctionId),
    constraint CK_Auction_StartPrice     check (StartPrice > 0),
    constraint CK_Auction_ReservePrice   check (ReservePrice is null or ReservePrice >= StartPrice),
    constraint CK_Auction_BidIncrement   check (BidIncrement > 0),
    constraint CK_Auction_EndsAfterStart check (EndsAt > StartsAt),
    constraint CK_Auction_Status         check (Status in ('Draft', 'Live', 'Ended', 'Cancelled'))
);
go

create table Sales.Bid
(
    BidId     bigint identity(1,1) not null,
    AuctionId int                  not null,              
    MemberId  uniqueidentifier     not null,              
    Amount    decimal(12,2)        not null,
    PlacedAt  datetime2(3)         not null
        constraint DF_Bid_PlacedAt default sysutcdatetime(),
    IpAddress varchar(45)          not null,             

    constraint PK_Bid                primary key (BidId),
    constraint CK_Bid_Amount         check (Amount > 0),
    constraint UQ_Bid_Auction_Amount unique (AuctionId, Amount)
);
go

create table Sales.AuctionFollow
(
    MemberId   uniqueidentifier not null,                 
    AuctionId  int              not null,                 
    FollowedAt datetime2(3)     not null
        constraint DF_AuctionFollow_FollowedAt default sysutcdatetime(),

    constraint PK_AuctionFollow primary key (MemberId, AuctionId)
);
go

/* =====================================================================
    ALTER
   ===================================================================== */


alter table Membership.Member
    add constraint FK_Member_City
    foreign key (CityId) references Membership.City (CityId);
go

alter table Membership.Member
    add constraint FK_Member_Member_InvitedBy
    foreign key (InvitedByMemberId) references Membership.Member (MemberId);
go

alter table Membership.Wallet
    add constraint FK_Wallet_Member
    foreign key (MemberId) references Membership.Member (MemberId);
go

alter table Logistics.Warehouse
    add constraint FK_Warehouse_City
    foreign key (CityId) references Membership.City (CityId);
go

alter table Logistics.Employee
    add constraint FK_Employee_Member
    foreign key (MemberId) references Membership.Member (MemberId);
go
alter table Logistics.Employee
    add constraint FK_Employee_Warehouse
    foreign key (WarehouseId) references Logistics.Warehouse (WarehouseId);
go
alter table Logistics.Warehouse
    add constraint FK_Warehouse_Employee_Manager
    foreign key (ManagerId) references Logistics.Employee (MemberId);
go
alter table Catalog.Category
    add constraint FK_Category_Category_Parent
    foreign key (ParentCategoryId) references Catalog.Category (CategoryId);
go
alter table Catalog.Item
    add constraint FK_Item_Member_Seller
    foreign key (SellerId) references Membership.Member (MemberId);
go
alter table Catalog.Item
    add constraint FK_Item_Member_Inspector
    foreign key (InspectorId) references Membership.Member (MemberId);
go
alter table Catalog.Item
    add constraint FK_Item_Category
    foreign key (CategoryId) references Catalog.Category (CategoryId);
go
alter table Catalog.Item
    add constraint FK_Item_Warehouse
    foreign key (WarehouseId) references Logistics.Warehouse (WarehouseId);
go
alter table Catalog.ItemPhoto
    add constraint FK_ItemPhoto_Item
    foreign key (ItemId) references Catalog.Item (ItemId)
    on delete cascade;
go
alter table Sales.Auction
    add constraint FK_Auction_Item
    foreign key (ItemId) references Catalog.Item (ItemId);
go
alter table Sales.Bid
    add constraint FK_Bid_Auction
    foreign key (AuctionId) references Sales.Auction (AuctionId);
go
alter table Sales.Bid
    add constraint FK_Bid_Member
    foreign key (MemberId) references Membership.Member (MemberId);
go
alter table Sales.AuctionFollow
    add constraint FK_AuctionFollow_Member
    foreign key (MemberId) references Membership.Member (MemberId);
go
alter table Sales.AuctionFollow
    add constraint FK_AuctionFollow_Auction
    foreign key (AuctionId) references Sales.Auction (AuctionId);
go
--3.2
alter table Membership.Member
add AppLanguage char(2) not null 
constraint df_Member_AppLanguage default 'ar'
constraint CK_Member_AppLanguage check (AppLanguage in ('ar', 'en'))


--3.3
alter table Catalog.Item
add IsFeatured bit not null
constraint DF_Item_IsFeatured default 0;




--3.4
exec sp_rename 'Sales.Bid.IpAddress', 'DeviceIp', 'COLUMN';

alter table Logistics.Warehouse drop constraint CK_Warehouse_Capacity;
go
exec sp_rename 'Logistics.Warehouse.Capacity', 'MaxItems', 'COLUMN';
go
alter table Logistics.Warehouse
    add constraint CK_Warehouse_MaxItems check (MaxItems > 0);
go

--3.5
alter table Membership.Member
alter column FullName nvarchar(150) not null ;

--3.6
alter table Logistics.Warehouse 
drop constraint CK_Warehouse_MaxItems


alter table Logistics.Warehouse
alter column MaxItems smallint not null

alter table Logistics.Warehouse 
add constraint CK_Warehouse_MaxItems check (MaxItems > 0)

--3.7
alter table Catalog.Category drop constraint CK_Category_CommissionPct;
go
alter table Catalog.Category
    add constraint CK_Category_CommissionPct check (CommissionPct between 0 and 25);
go

--3.8
alter table Sales.Auction drop constraint CK_Auction_Status
alter table Sales.Auction drop constraint DF_Auction_Status

go
alter table Sales.Auction 
add constraint CK_Auction_Status check (status in ('PendingReview','Draft', 'Live', 'Ended', 'Cancelled'))
alter table Sales.Auction
add constraint dflt_Auction_Status default 'PendingReview' for Status

--3.9
alter table Sales.Auction add BuyNowPrice decimal(12,2) null;
go
alter table Sales.Auction with check
    add constraint CK_Auction_BuyNowPrice
        check (BuyNowPrice is null or BuyNowPrice > StartPrice);
go


--3.10
alter table Membership.Member
    add constraint UQ_Member_Mobile unique (Mobile);


--3.11
alter table Membership.Member add VerifiedAt datetime2(3) null;
go
alter table Membership.Member drop constraint DF_Member_IsVerified;
go
alter table Membership.Member drop column IsVerified;
go



-- 3.12
create schema Marketing;
go
alter schema Marketing transfer Sales.AuctionFollow;
go
