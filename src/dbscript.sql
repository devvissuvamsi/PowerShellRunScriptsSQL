USE [DBA]
GO


-- log the details of each Deployment request
CREATE TABLE [dbo].[DeploymentConfig](
   [InitFile] [varchar](2000) NOT NULL,
   [InitFileDate] [datetime] NOT NULL,
   [TargetServer] [varchar](100) NULL,
   [TargetServerDatabaseName] [varchar](100) NULL,
   [TargetServerUserName] [varchar](100) NULL,
   [ScriptFolder] [varchar](600) NULL,
   [Requestor] [varchar](100) NOT NULL,
   [Tag] [varchar](150) not NULL,
   [id] [int] IDENTITY(1,1) primary key,
)
GO

-- log the deployment result of each script 
CREATE TABLE [dbo].[DeploymentHistory](
   [FullPath] [varchar](800) NULL,
   [Tag] [varchar](150) NULL,
   [TargetServer] [varchar](60) NULL,
   [TargetServerDatabaseName] [varchar](100) NULL,
   [TargetServerUserName] [varchar](100) NULL,
   [Status] [varchar](20) NULL,
   [Message] [varchar](6000) NULL,
   [DeployDate] [datetime] NULL,
   [ConfigID] [int] NULL,
   [id] [int] IDENTITY primary key
);
GO

ALTER TABLE [dbo].[DeploymentHistory] ADD  DEFAULT ('not started') FOR [Status];
ALTER TABLE [dbo].[DeploymentHistory] ADD  DEFAULT (getdate()) FOR [DeployDate];
ALTER TABLE [dbo].[DeploymentHistory]  WITH NOCHECK ADD FOREIGN KEY([ConfigID])
REFERENCES [dbo].[DeploymentConfig] ([id]);
GO