function result = userSettingsFileNameFromProfileName(profileName)
    appDataPath = getenv('APPDATA') ;
    profilesFolderPath = fullfile(appDataPath, 'janelia', 'wavesurfer', 'profiles') ;
    result = fullfile(profilesFolderPath, sprintf('%s.wsu', profileName)) ;
end
