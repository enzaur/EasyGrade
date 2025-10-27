<script lang="ts">
    import { read, utils } from "xlsx";
  
    let file: File | null = null;
    let data: { No: number; Code: string; Name: string }[] = [];
  
    function handleFileChange(event: Event) {
      const input = event.target as HTMLInputElement;
      if (input.files && input.files.length > 0) {
        file = input.files[0];
        processFile(file);
      }
    }
  
    function toTitleCase(str: string) {
      if (!str) return "";
      return str
        .toLowerCase()
        .split(" ")
        .map(word => word.charAt(0).toUpperCase() + word.slice(1))
        .join(" ");
    }
  
    function processFile(file: File) {
      const reader = new FileReader();
  
      reader.onload = (e) => {
        const arrayBuffer = e.target?.result;
        if (!arrayBuffer) return;
  
        const workbook = read(arrayBuffer, { type: "array" });
        const sheetName = workbook.SheetNames[0];
        const worksheet = workbook.Sheets[sheetName];
  
        const json = utils.sheet_to_json(worksheet, { defval: "" });
  
        data = json
          .map((row: any) => ({
            No: row["No"] || "",
            Code: row["Code"] || "",
            Name: toTitleCase(row["Name"] || "")
          }))
          .filter(row => row.Code && row.Name);
      };
  
      reader.readAsArrayBuffer(file);
    }
  </script>
  
  <section class="p-4">
    <h2 class="text-xl font-bold mb-3">Upload XLSX/CSV</h2>
    <input type="file" accept=".xlsx,.xls,.csv" on:change={handleFileChange} />
  
    {#if data.length > 0}
      <h3 class="mt-4 font-semibold font-sans">Data Preview</h3>
      <table class="border-collapse border border-gray-300 mt-2">
        <thead>
          <tr>
            <th class="border border-gray-300 px-2 py-1">No</th>
            <th class="border border-gray-300 px-2 py-1">Code</th>
            <th class="border border-gray-300 px-2 py-1">Name</th>
          </tr>
        </thead>
        <tbody>
          {#each data as row}
            <tr>
              <td class="border border-gray-300 px-2 py-1">{row.No}</td>
              <td class="border border-gray-300 px-2 py-1">{row.Code}</td>
              <td class="border border-gray-300 px-2 py-1">{row.Name}</td>
            </tr>
          {/each}
        </tbody>
      </table>
    {/if}
  </section>
  