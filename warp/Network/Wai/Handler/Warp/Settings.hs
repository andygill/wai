{-# LANGUAGE OverloadedStrings, ScopedTypeVariables, ViewPatterns #-}
{-# LANGUAGE PatternGuards #-}

module Network.Wai.Handler.Warp.Settings where

import Control.Exception
import Control.Monad (when)
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import Data.Streaming.Network (HostPreference)
import GHC.IO.Exception (IOErrorType(..))
import qualified Network.HTTP.Types as H
import Network.Socket (SockAddr)
import Network.Wai
import Network.Wai.Handler.Warp.Timeout
import Network.Wai.Handler.Warp.Types
import System.IO (stderr)
import System.IO.Error (ioeGetErrorType)
import qualified Data.Text.Lazy as TL
import qualified Data.Text.Lazy.Encoding as TLE

-- | Various Warp server settings. This is purposely kept as an abstract data
-- type so that new settings can be added without breaking backwards
-- compatibility. In order to create a 'Settings' value, use 'defaultSettings'
-- and record syntax to modify individual records. For example:
--
-- > defaultSettings { settingsTimeout = 20 }
data Settings = Settings
    { settingsPort :: Int -- ^ Port to listen on. Default value: 3000
    , settingsHost :: HostPreference -- ^ Default value: HostIPv4
    , settingsOnException :: Maybe Request -> SomeException -> IO () -- ^ What to do with exceptions thrown by either the application or server. Default: ignore server-generated exceptions (see 'InvalidRequest') and print application-generated applications to stderr.
    , settingsOnExceptionResponse :: SomeException -> Response
      -- ^ A function to create `Response` when an exception occurs.
      --
      -- Default: 500, text/plain, \"Something went wrong\"
      --
      -- Since 2.0.3
    , settingsOnOpen :: SockAddr -> IO Bool -- ^ What to do when a connection is open. When 'False' is returned, the connection is closed immediately. Otherwise, the connection is going on. Default: always returns 'True'.
    , settingsOnClose :: SockAddr -> IO ()  -- ^ What to do when a connection is close. Default: do nothing.
    , settingsTimeout :: Int -- ^ Timeout value in seconds. Default value: 30
    , settingsManager :: Maybe Manager -- ^ Use an existing timeout manager instead of spawning a new one. If used, 'settingsTimeout' is ignored. Default is 'Nothing'
    , settingsFdCacheDuration :: Int -- ^ Cache duratoin time of file descriptors in seconds. 0 means that the cache mechanism is not used. Default value: 10
    , settingsBeforeMainLoop :: IO ()
      -- ^ Code to run after the listening socket is ready but before entering
      -- the main event loop. Useful for signaling to tests that they can start
      -- running, or to drop permissions after binding to a restricted port.
      --
      -- Default: do nothing.
      --
      -- Since 1.3.6
    , settingsNoParsePath :: Bool
      -- ^ Perform no parsing on the rawPathInfo.
      --
      -- This is useful for writing HTTP proxies.
      --
      -- Default: False
      --
      -- Since 2.0.3
    }

-- | The default settings for the Warp server. See the individual settings for
-- the default value.
defaultSettings :: Settings
defaultSettings = Settings
    { settingsPort = 3000
    , settingsHost = "*4"
    , settingsOnException = defaultExceptionHandler
    , settingsOnExceptionResponse = defaultExceptionResponse
    , settingsOnOpen = const $ return True
    , settingsOnClose = const $ return ()
    , settingsTimeout = 30
    , settingsManager = Nothing
    , settingsFdCacheDuration = 10
    , settingsBeforeMainLoop = return ()
    , settingsNoParsePath = False
    }

-- | Apply the logic provided by 'defaultExceptionHandler' to determine if an
-- exception should be shown or not. The goal is to hide exceptions which occur
-- under the normal course of the web server running.
--
-- Since 2.1.3
defaultShouldDisplayException :: SomeException -> Bool
defaultShouldDisplayException se
    | Just ThreadKilled <- fromException se = False
    | Just (_ :: InvalidRequest) <- fromException se = False
    | Just (ioeGetErrorType -> et) <- fromException se
        , et == ResourceVanished || et == InvalidArgument = False
    | Just TimeoutThread <- fromException se = False
    | otherwise = True

defaultExceptionHandler :: Maybe Request -> SomeException -> IO ()
defaultExceptionHandler _ e =
    when (defaultShouldDisplayException e)
        $ TIO.hPutStrLn stderr $ T.pack $ show e

defaultExceptionResponse :: SomeException -> Response
defaultExceptionResponse _ = responseLBS H.internalServerError500 [(H.hContentType, "text/plain; charset=utf-8")] "Something went wrong"

-- | Default implementation of 'settingsOnExceptionResponse' for the debugging purpose. 500, text/plain, a showed exception.
exceptionResponseForDebug :: SomeException -> Response
exceptionResponseForDebug e = responseLBS H.internalServerError500 [(H.hContentType, "text/plain; charset=utf-8")] (TLE.encodeUtf8 $ TL.pack $ "Exception: " ++ show e)

{-# DEPRECATED settingsPort "Use setPort instead" #-}
{-# DEPRECATED settingsHost "Use setHost instead" #-}
{-# DEPRECATED settingsOnException "Use setOnException instead" #-}
{-# DEPRECATED settingsOnExceptionResponse "Use setOnExceptionResponse instead" #-}
{-# DEPRECATED settingsOnOpen "Use setOnOpen instead" #-}
{-# DEPRECATED settingsOnClose "Use setOnClose instead" #-}
{-# DEPRECATED settingsTimeout "Use setTimeout instead" #-}
{-# DEPRECATED settingsManager "Use setManager instead" #-}
{-# DEPRECATED settingsFdCacheDuration "Use setFdCacheDuration instead" #-}
{-# DEPRECATED settingsBeforeMainLoop "Use setBeforeMainLoop instead" #-}
{-# DEPRECATED settingsNoParsePath "Use setNoParsePath instead" #-}
