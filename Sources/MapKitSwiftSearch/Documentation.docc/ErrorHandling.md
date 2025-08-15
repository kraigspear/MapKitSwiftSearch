# Error Handling

Learn how to properly handle different error scenarios when using MapKitSwiftSearch.

## Overview

MapKitSwiftSearch provides comprehensive error handling through the `LocationSearchError` enum. Understanding these errors and how to handle them properly is essential for creating a robust location search experience.

## LocationSearchError Types

### Overview of Error Cases

```swift
public enum LocationSearchError: LocalizedError, Equatable {
    case searchCompletionFailed
    case mapKitError(MKError)
    case invalidSearchCriteria
    case duplicateSearchCriteria
    case debounce
}
```

## Error Scenarios and Handling

### 1. Debounce Errors

**When it occurs**: When a search request is cancelled due to debouncing (user typing quickly).

**How to handle**: This is typically expected behavior and should be ignored.

```swift
do {
    let results = try await locationSearch.search(queryFragment: searchText)
    // Handle successful results
    updateUI(with: results)
} catch LocationSearchError.debounce {
    // This is normal - user is typing quickly
    // Don't show an error to the user
    print("Search debounced - this is expected")
} catch {
    // Handle other errors
    handleSearchError(error)
}
```

### 2. Invalid Search Criteria

**When it occurs**: When the search query doesn't meet minimum character requirements.

**How to handle**: Clear results and optionally show a hint to the user.

```swift
do {
    let results = try await locationSearch.search(queryFragment: searchText)
    updateUI(with: results)
    clearErrorState()
} catch LocationSearchError.invalidSearchCriteria {
    // Clear results and optionally show hint
    clearResults()
    showHint("Enter at least 5 characters to search")
} catch LocationSearchError.debounce {
    // Ignore debounced requests
} catch {
    handleUnexpectedError(error)
}
```

### 3. Duplicate Search Criteria

**When it occurs**: When the same search query is submitted consecutively.

**How to handle**: This prevents unnecessary API calls. Usually ignore this error.

```swift
do {
    let results = try await locationSearch.search(queryFragment: searchText)
    updateUI(with: results)
} catch LocationSearchError.duplicateSearchCriteria {
    // Same search as before - no action needed
    print("Duplicate search prevented")
} catch LocationSearchError.debounce {
    // Ignore debounced requests
} catch {
    handleSearchError(error)
}
```

### 4. MapKit Errors

**When it occurs**: When MapKit encounters network issues, location services problems, or other system-level errors.

**How to handle**: These require user-facing error messages and potential retry mechanisms.

```swift
do {
    let placemark = try await locationSearch.placemark(for: searchCompletion)
    // Handle successful placemark
} catch LocationSearchError.mapKitError(let mkError) {
    handleMapKitError(mkError)
} catch {
    handleUnexpectedError(error)
}

func handleMapKitError(_ mkError: MKError) {
    switch mkError.code {
    case .network:
        showErrorMessage("Network connection required for location search")
    case .locationUnknown:
        showErrorMessage("Unable to determine current location")
    case .directionsNotFound:
        showErrorMessage("Location not found")
    case .serverFailure:
        showErrorMessage("Location service temporarily unavailable")
    default:
        showErrorMessage("Location search failed: \(mkError.localizedDescription)")
    }
}
```

### 5. Search Completion Failed

**When it occurs**: When the search operation fails for unexpected reasons.

**How to handle**: Show a generic error message and allow retry.

```swift
do {
    let results = try await locationSearch.search(queryFragment: searchText)
    updateUI(with: results)
} catch LocationSearchError.searchCompletionFailed {
    showErrorMessage("Search failed. Please try again.")
    enableRetry()
} catch {
    handleUnexpectedError(error)
}
```

## Comprehensive Error Handling Pattern

Here's a complete error handling implementation:

```swift
@MainActor
class LocationSearchViewModel: ObservableObject {
    @Published var searchResults: [LocalSearchCompletion] = []
    @Published var isSearching = false
    @Published var errorMessage: String?
    @Published var showRetryButton = false
    
    private let locationSearch = LocationSearch()
    private var lastSearchQuery: String?
    
    func performSearch(_ query: String) async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        lastSearchQuery = trimmedQuery
        
        // Clear previous error state
        errorMessage = nil
        showRetryButton = false
        
        guard !trimmedQuery.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        
        do {
            let results = try await locationSearch.search(queryFragment: trimmedQuery)
            searchResults = results
            
        } catch LocationSearchError.debounce {
            // Normal behavior during rapid typing - ignore
            break
            
        } catch LocationSearchError.invalidSearchCriteria {
            // Not enough characters - clear results
            searchResults = []
            
        } catch LocationSearchError.duplicateSearchCriteria {
            // Same search as before - ignore
            break
            
        } catch LocationSearchError.mapKitError(let mkError) {
            searchResults = []
            handleMapKitError(mkError)
            
        } catch LocationSearchError.searchCompletionFailed {
            searchResults = []
            errorMessage = "Search failed. Please try again."
            showRetryButton = true
            
        } catch {
            searchResults = []
            errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
            showRetryButton = true
        }
        
        isSearching = false
    }
    
    func retry() {
        guard let lastQuery = lastSearchQuery else { return }
        Task {
            await performSearch(lastQuery)
        }
    }
    
    private func handleMapKitError(_ mkError: MKError) {
        switch mkError.code {
        case .network:
            errorMessage = "Please check your internet connection and try again."
            showRetryButton = true
            
        case .locationUnknown:
            errorMessage = "Unable to determine your location. Please enable location services."
            
        case .directionsNotFound:
            errorMessage = "No locations found matching your search."
            
        case .serverFailure:
            errorMessage = "Location service is temporarily unavailable."
            showRetryButton = true
            
        default:
            errorMessage = "Search failed: \(mkError.localizedDescription)"
            showRetryButton = true
        }
    }
}
```

## SwiftUI Error Display

Here's how to display errors effectively in SwiftUI:

```swift
struct LocationSearchView: View {
    @StateObject private var viewModel = LocationSearchViewModel()
    @State private var searchText = ""
    
    var body: some View {
        VStack {
            SearchField(text: $searchText) { query in
                Task {
                    await viewModel.performSearch(query)
                }
            }
            
            // Error handling UI
            if let errorMessage = viewModel.errorMessage {
                ErrorView(
                    message: errorMessage,
                    showRetry: viewModel.showRetryButton,
                    onRetry: viewModel.retry
                )
            }
            
            // Loading indicator
            if viewModel.isSearching {
                LoadingView()
            }
            
            // Results list
            List(viewModel.searchResults) { result in
                LocationRow(result: result) {
                    Task {
                        await selectLocation(result)
                    }
                }
            }
        }
    }
    
    private func selectLocation(_ completion: LocalSearchCompletion) async {
        do {
            let placemark = try await viewModel.locationSearch.placemark(for: completion)
            // Handle successful selection
        } catch LocationSearchError.mapKitError(let mkError) {
            // Handle placemark fetch errors
            await MainActor.run {
                viewModel.errorMessage = "Failed to get location details: \(mkError.localizedDescription)"
                viewModel.showRetryButton = false
            }
        } catch {
            await MainActor.run {
                viewModel.errorMessage = "Failed to get location details"
                viewModel.showRetryButton = false
            }
        }
    }
}

struct ErrorView: View {
    let message: String
    let showRetry: Bool
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.orange)
                .font(.title2)
            
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            if showRetry {
                Button("Try Again") {
                    onRetry()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}
```

## UIKit Error Handling

For UIKit applications:

```swift
class LocationSearchViewController: UIViewController {
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var errorView: UIView!
    @IBOutlet weak var errorLabel: UILabel!
    @IBOutlet weak var retryButton: UIButton!
    @IBOutlet weak var loadingIndicator: UIActivityIndicatorView!
    
    private let locationSearch = LocationSearch()
    private var searchResults: [LocalSearchCompletion] = []
    private var lastSearchQuery: String?
    
    @IBAction func retryTapped(_ sender: UIButton) {
        guard let lastQuery = lastSearchQuery else { return }
        performSearch(query: lastQuery)
    }
    
    private func performSearch(query: String) {
        lastSearchQuery = query
        hideError()
        
        guard !query.isEmpty else {
            searchResults = []
            tableView.reloadData()
            return
        }
        
        showLoading(true)
        
        Task {
            do {
                let results = try await locationSearch.search(queryFragment: query)
                await MainActor.run {
                    self.searchResults = results
                    self.tableView.reloadData()
                    self.showLoading(false)
                }
            } catch LocationSearchError.debounce {
                await MainActor.run {
                    self.showLoading(false)
                }
            } catch LocationSearchError.invalidSearchCriteria {
                await MainActor.run {
                    self.searchResults = []
                    self.tableView.reloadData()
                    self.showLoading(false)
                }
            } catch LocationSearchError.mapKitError(let mkError) {
                await MainActor.run {
                    self.handleMapKitError(mkError)
                }
            } catch {
                await MainActor.run {
                    self.showError("Search failed. Please try again.", showRetry: true)
                }
            }
        }
    }
    
    private func handleMapKitError(_ mkError: MKError) {
        let message: String
        let showRetry: Bool
        
        switch mkError.code {
        case .network:
            message = "Please check your internet connection."
            showRetry = true
        case .locationUnknown:
            message = "Unable to determine location. Please enable location services."
            showRetry = false
        default:
            message = "Search failed: \(mkError.localizedDescription)"
            showRetry = true
        }
        
        showError(message, showRetry: showRetry)
    }
    
    private func showError(_ message: String, showRetry: Bool) {
        searchResults = []
        tableView.reloadData()
        showLoading(false)
        
        errorLabel.text = message
        retryButton.isHidden = !showRetry
        errorView.isHidden = false
    }
    
    private func hideError() {
        errorView.isHidden = true
    }
    
    private func showLoading(_ show: Bool) {
        if show {
            loadingIndicator.startAnimating()
        } else {
            loadingIndicator.stopAnimating()
        }
    }
}
```

## Best Practices

### 1. Graceful Degradation
- Always provide fallback behavior when searches fail
- Don't let errors break the entire user experience
- Maintain app functionality even when location services are unavailable

### 2. User Communication
- Use clear, non-technical error messages
- Provide actionable guidance when possible
- Distinguish between temporary and permanent failures

### 3. Retry Mechanisms
- Offer retry for network-related failures
- Don't automatically retry for user input errors
- Implement exponential backoff for repeated failures

### 4. Error Logging
- Log errors for debugging and analytics
- Include relevant context (search query, device state)
- Respect user privacy in error reports

## Next Steps

- **<doc:AdvancedUsage>** - Learn about performance optimization and customization
- **<doc:PlatformDifferences>** - Understand iOS vs macOS specific considerations
- **<doc:BasicSearchFunctionality>** - Review basic search patterns