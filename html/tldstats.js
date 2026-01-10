function createChart(id, dataObj) {
  const ctx = document.getElementById(id);
  if (!ctx) {
    return;
  }

  if (!dataObj) {
    return;
  }

  const chart = new Chart(ctx, {
    type: 'line',
    data: {
      labels: dataObj.labels,
      datasets: [{
        data: dataObj.data,
        label: `.${id}`,
        fill: false,
        borderColor: 'rgb(0, 0, 255)',
        tension: 0.1
      }]
    },
    options: {
      spanGaps: true,
      plugins: {
        legend: {
          display: false
        }
      }
    }
  });
}
