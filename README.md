# Seeruta App - Google Colab Integration

This repository contains the Seeruta app for offline map navigation and jeepney route planning in Cebu City.

## Overview

The Seeruta app is a Flutter application that provides:

- ✅ Offline map navigation using MapLibre
- ✅ GPS-based route recording and planning
- ✅ OCR-based code scanning for jeepney route identification
- ✅ Profile management with seen barangays tracking
- ✅ Fare calculation with LTFRB rates
- ✅ Route database for storing and managing route information

## Features

### 1. Google Colab Integration

This repository includes a Jupyter notebook that provides **seamless Google Colab integration** for the Seeruta app:

- **Import/Fork Instructions**: Easy-to-follow steps to copy the repository to Google Colab
- **Environment Setup**: Automatic installation of all dependencies
- **Development Workflow**: Commands to run, build, and test the app directly from Colab
- **Version Control**: Git operations integrated into Colab interface

### 2. Executable Builder

A comprehensive guide for building Windows executables:

- **PyInstaller Configuration**: Step-by-step setup for creating standalone .exe files
- **Advanced Build Options**: Custom packaging for offline map delivery
- **Installer Creation**: Batch scripts for easy installation
- **Testing and Verification**: Commands to validate the built executable

### 3. Download Interface

A professional download page with:

- **Real-time Build Progress**: Visual feedback during the build process
- **Automatic File Preparation**: Ready-to-download executable with metadata
- **Release Information**: Changelog and technical specifications
- **Support Features**: Direct contact and troubleshooting options

## Quick Start

### Google Colab Integration

1. **Open in Google Colab**:
   - Click the link to open `google_colab_connection.ipynb` in Google Colab
   - Or copy the notebook to your Google Drive and run it

2. **Follow the Instructions**:
   - Fork the repository (if needed)
   - Mount your Google Drive
   - Install dependencies
   - Set up the development environment

3. **Start Developing**:
   - Run Flutter commands
   - Edit code directly in Colab
   - Save and commit changes
   - Push back to your GitHub repository

### Building Executable

1. **Open the Build Notebook**:
   - Navigate to `build_exe_executable.ipynb`
   - Follow the step-by-step build instructions

2. **Build Process**:
   - Install PyInstaller and related tools
   - Configure build specifications
   - Create the executable
   - Test and verify

3. **Download**:
   - Open `seeruta_download_page.html`
   - Monitor build progress
   - Download the executable when ready

## Technical Details

### File Structure

- **google_colab_connection.ipynb** - Google Colab integration guide
- **build_exe_executable.ipynb** - Windows executable builder
- **seeruta_download_page.html** - Download and build progress interface

### Development Stack

- **Frontend**: Flutter (Dart)
- **Maps**: MapLibre GL
- **Backend**: SQLite, Flask
- **Data Processing**: Pandas, NumPy
- **Geospatial**: Geopy
- **Packaging**: PyInstaller, setuptools

### Key Features Implemented

1. **Route Database**: SQLite with haversine calculations
2. **Map Integration**: Offline vector tiles with MapLibre
3. **User Interface**: Responsive Flutter app
4. **Code Scanning**: OCR integration with ML Kit
5. **GPS Tracking**: Real-time location recording
6. **Profile System**: Seen barangays tracking

## Usage Examples

### Google Colab Commands

```python
# Import the repository and set up the environment
from google.colab import drive
drive.mount('/content/drive')

# Navigate to the project directory
import os
os.chdir('/content/drive/My Drive/seeruta-app')

# Install dependencies
!pip install -r requirements.txt

# Run Flutter analysis
!flutter analyze

# Build the APK
!flutter build apk --debug
```

### Building with PyInstaller

```python
# Create executable using PyInstaller
import subprocess
import sys

subprocess.check_call([sys.executable, '-m', 'PyInstaller', '--specpath', '.', '--name', 'SeerutaApp', '--windowed'])
```

## Benefits

### For Developers

- **Cloud Development**: Work from anywhere with Google Colab
- **Shared Development**: Collaborate with teammates easily
- **No Local Setup**: Run code without installing Flutter/Dart locally
- **Backup**: Automatic saving to Google Drive
- **Testing**: Quick testing and debugging

### For Users

- **Standalone Executable**: Run without Flutter installation
- **Offline Functionality**: No internet required after download
- **Easy Installation**: Simple batch file installer
- **Professional Interface**: Clean, user-friendly download page

## Support

### Documentation

- Google Colab notebook for setup
- Build instructions in `build_exe_executable.ipynb`
- Download page with progress tracking

### Troubleshooting

Common issues and solutions:

1. **Google Colab Mount Issues**: Ensure you're signed into the correct Google account
2. **Build Errors**: Check dependencies and install missing packages
3. **Download Problems**: Try a different browser or internet connection
4. **Installation Failures**: Run as administrator

### Contact

For issues or questions:

- GitHub Issues: Report bugs and feature requests
- Documentation: Read the notebooks for detailed instructions
- Support: Use the contact form in the download page

## License

This project is licensed under the terms of the MIT License.

## Contributing

Contributions are welcome! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch
3. Implement your changes
4. Test thoroughly
5. Submit a pull request

## Acknowledgments

Special thanks to:

- Google Colab for cloud development platform
- Flutter/Dart for the app framework
- MapLibre for offline maps
- PyInstaller for executable packaging
- The Seeruta app community

## Future Development

Potential enhancements:

- **Mobile Apps**: iOS and Android versions
- **Web Version**: Progressive web app
- **Enhanced Maps**: Additional map providers
- **Advanced Features**: Real-time traffic, multiple transportation modes
- **Integration**: Public transportation APIs

## Changelog

### Version 1.0.0
- Initial release with Google Colab integration
- Windows executable builder
- Professional download interface
- Complete feature set

### Upcoming Features
- Cross-platform mobile apps
- Enhanced map providers
- Advanced route optimization
- Real-time traffic integration

---

*Built with ❤️ for the Seeruta community*