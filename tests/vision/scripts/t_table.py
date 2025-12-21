# Test charm.table() functionality
import charm

# Basic table without headers
print("Basic table:")
data = [["Alice", "25", "Engineer"], ["Bob", "30", "Designer"]]
charm.table(data)

# Table with headers
print("\nWith headers:")
data = [["Name", "Age", "Role"], ["Alice", "25", "Engineer"], ["Bob", "30", "Designer"]]
charm.table(data, headers=True)

# Different border styles
print("\nRounded border:")
charm.table([["A", "B"], ["1", "2"]], border="rounded")

print("\nDouble border:")
charm.table([["X", "Y"], ["3", "4"]], border="double")

print("\nHeavy border:")
charm.table([["P", "Q"], ["5", "6"]], border="heavy")

# Single row with headers
print("\nSingle data row:")
charm.table([["Status", "Count"], ["OK", "42"]], headers=True)
